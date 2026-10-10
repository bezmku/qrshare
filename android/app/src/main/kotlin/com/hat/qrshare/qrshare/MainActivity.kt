package com.hat.qrshare.qrshare

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var joinCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qrshare/hotspot")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startHotspot" -> startHotspot(result)
                    "stopHotspot" -> stopHotspot(result)
                    "joinHotspot" -> {
                        val ssid = call.argument<String>("ssid")
                        val password = call.argument<String>("password")
                        if (ssid == null || password == null) {
                            result.error("bad_args", "ssid/password required", null)
                        } else {
                            joinHotspot(ssid, password, result)
                        }
                    }
                    "leaveHotspot" -> {
                        leaveHotspot()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qrshare/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "publishToDownloads" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        if (path == null || name == null) {
                            result.error("bad_args", "path/name required", null)
                        } else {
                            publishToDownloads(path, name, result)
                        }
                    }
                    "openFile" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("bad_args", "uri required", null)
                        } else {
                            openFile(uri, result)
                        }
                    }
                    "shareFile" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("bad_args", "uri required", null)
                        } else {
                            shareFile(uri, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun startHotspot(result: MethodChannel.Result) {
        reservation?.close()
        reservation = null

        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        try {
            wifiManager.startLocalOnlyHotspot(
                object : WifiManager.LocalOnlyHotspotCallback() {
                    override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                        reservation = res
                        val ssid: String
                        val password: String
                        var bssid = ""
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val cfg = res.softApConfiguration
                            ssid = cfg.ssid ?: ""
                            password = cfg.passphrase ?: ""
                            bssid = cfg.bssid?.toString() ?: ""
                        } else {
                            val cfg = res.wifiConfiguration
                            ssid = (cfg?.SSID ?: "").trim('"', '\n', ' ')
                            password = (cfg?.preSharedKey ?: "").trim('"')
                            bssid = cfg?.BSSID ?: ""
                        }
                        result.success(mapOf("ssid" to ssid, "password" to password, "bssid" to bssid))
                    }

                    override fun onFailed(reason: Int) {
                        val message = when (reason) {
                            ERROR_NO_CHANNEL -> "No free Wi-Fi channel"
                            ERROR_INCOMPATIBLE_MODE -> "Incompatible mode"
                            ERROR_TETHERING_DISALLOWED -> "Tethering not allowed on this device"
                            ERROR_GENERIC -> "Generic error (is location turned on?)"
                            else -> "Unknown error ($reason)"
                        }
                        result.error("hotspot_failed", message, null)
                    }

                    override fun onStopped() {
                        reservation = null
                    }
                },
                Handler(Looper.getMainLooper())
            )
        } catch (e: SecurityException) {
            result.error("permission_denied", e.message, null)
        } catch (e: IllegalStateException) {
            result.error("hotspot_failed", e.message, null)
        }
    }

    private fun stopHotspot(result: MethodChannel.Result) {
        reservation?.close()
        reservation = null
        result.success(null)
    }

    private fun joinHotspot(ssid: String, password: String, result: MethodChannel.Result) {
        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(password)
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val connectivityManager =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        leaveHotspot()
        var responded = false

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                super.onAvailable(network)
                connectivityManager.bindProcessToNetwork(network)
                val linkProperties: LinkProperties? =
                    connectivityManager.getLinkProperties(network)
                val gateway = linkProperties?.routes
                    ?.firstOrNull { it.isDefaultRoute }
                    ?.gateway
                    ?.hostAddress
                if (responded) return
                responded = true
                if (gateway == null) {
                    result.error("join_failed", "Could not determine gateway IP", null)
                } else {
                    result.success(gateway)
                }
            }

            override fun onUnavailable() {
                super.onUnavailable()
                if (responded) return
                responded = true
                result.error("join_failed", "Connection denied or network not found", null)
            }
        }
        joinCallback = callback
        connectivityManager.requestNetwork(request, callback, Handler(Looper.getMainLooper()))
    }

    @Suppress("DEPRECATION")
    private fun leaveHotspot() {
        val callback = joinCallback ?: return
        val connectivityManager =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        try {
            connectivityManager.unregisterNetworkCallback(callback)
        } catch (_: Exception) {
        }
        connectivityManager.bindProcessToNetwork(null)
        joinCallback = null
    }

    private fun publishToDownloads(path: String, name: String, result: MethodChannel.Result) {
        try {
            val source = File(path)
            if (!source.exists()) {
                result.error("not_found", "Source file missing", null)
                return
            }
            val resolver = applicationContext.contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, guessMime(name))
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values)
            if (uri == null) {
                result.error("publish_failed", "MediaStore insert failed", null)
                return
            }
            resolver.openOutputStream(uri)?.use { out ->
                source.inputStream().use { input -> input.copyTo(out) }
            } ?: run {
                resolver.delete(uri, null, null)
                result.error("publish_failed", "Could not open output stream", null)
                return
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            result.success(uri.toString())
        } catch (e: Exception) {
            result.error("publish_failed", e.message, null)
        }
    }

    private fun guessMime(name: String): String =
        when (name.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "pdf" -> "application/pdf"
            "txt" -> "text/plain"
            "mp4" -> "video/mp4"
            "mp3" -> "audio/mpeg"
            "zip" -> "application/zip"
            else -> "application/octet-stream"
        }

    private fun openFile(uriString: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(uriString)
            val mime = applicationContext.contentResolver.getType(uri) ?: "*/*"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("open_failed", e.message, null)
        }
    }

    private fun shareFile(uriString: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(uriString)
            val mime = applicationContext.contentResolver.getType(uri) ?: "*/*"
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(
                Intent.createChooser(intent, "Share file")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            result.success(null)
        } catch (e: Exception) {
            result.error("share_failed", e.message, null)
        }
    }

    override fun onDestroy() {
        leaveHotspot()
        reservation?.close()
        reservation = null
        super.onDestroy()
    }
}
