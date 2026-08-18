package com.example.wearos_proxy_tools

import android.content.pm.PackageManager
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import moe.shizuku.server.IShizukuService
import rikka.shizuku.Shizuku
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "wearos_proxy_tools/shizuku"
        private const val REQUEST_CODE = 10001
    }

    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingAction: String? = null
    private val executor = Executors.newSingleThreadExecutor()

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode != REQUEST_CODE) return@OnRequestPermissionResultListener
        val result = pendingResult
        val action = pendingAction
        pendingResult = null
        pendingAction = null
        if (result != null) {
            if (grantResult == PackageManager.PERMISSION_GRANTED) {
                result.success(mapOf("granted" to true))
                action?.let { runCommand(it, emptyMap()) }
            } else {
                result.success(mapOf("granted" to false))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(availability())
                "requestPermission" -> {
                    val action = call.argument<String>("action")
                    if (isPermissionGranted()) {
                        result.success(mapOf("granted" to true))
                        action?.let { runCommand(it, emptyMap()) }
                    } else {
                        pendingResult = result
                        pendingAction = action
                        Shizuku.requestPermission(REQUEST_CODE)
                    }
                }
                "getProxy" -> runCommand("getProxy", emptyMap(), result)
                "setProxy" -> {
                    val value = call.argument<String>("value") ?: ""
                    runCommand("setProxy", mapOf("value" to value), result)
                }
                "clearProxy" -> runCommand("clearProxy", emptyMap(), result)
                else -> result.notImplemented()
            }
        }
        Shizuku.addRequestPermissionResultListener(permissionListener)
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        Shizuku.removeRequestPermissionResultListener(permissionListener)
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun availability(): Map<String, Any?> {
        val available = Shizuku.pingBinder()
        val granted = available && isPermissionGranted()
        return mapOf("available" to available, "granted" to granted)
    }

    private fun isPermissionGranted(): Boolean {
        if (!Shizuku.pingBinder()) return false
        return if (Shizuku.isPreV11()) {
            true
        } else {
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun runCommand(
        method: String,
        arguments: Map<String, String>,
        result: MethodChannel.Result? = null
    ) {
        executor.execute {
            try {
                ensurePermission()
                val output = when (method) {
                    "getProxy" -> getProxy()
                    "setProxy" -> setProxy(arguments["value"] ?: "")
                    "clearProxy" -> clearProxy()
                    else -> error("Unknown method: $method")
                }
                if (result != null) {
                    runOnUiThread { result.success(output) }
                }
            } catch (e: Exception) {
                if (result != null) {
                    runOnUiThread { result.error("SHIZUKU_ERROR", e.message ?: e.toString(), null) }
                }
            }
        }
    }

    private fun ensurePermission() {
        if (!Shizuku.pingBinder()) {
            throw IllegalStateException("Shizuku 未运行或未连接")
        }
        if (!isPermissionGranted()) {
            throw IllegalStateException("未授予 Shizuku 权限")
        }
    }

    private fun exec(vararg command: String): ExecResult {
        val binder = Shizuku.getBinder()
            ?: throw IllegalStateException("无法获取 Shizuku Binder")
        val service = IShizukuService.Stub.asInterface(binder)
        val process = service.newProcess(command, null, null)
        val stdout = ParcelFileDescriptor.AutoCloseInputStream(process.inputStream)
            .bufferedReader().use { it.readText().trim() }
        val stderr = ParcelFileDescriptor.AutoCloseInputStream(process.errorStream)
            .bufferedReader().use { it.readText().trim() }
        val exitCode = process.waitFor()
        return ExecResult(exitCode, stdout, stderr)
    }

    private fun getProxy(): Map<String, Any?> {
        val res = exec("settings", "get", "global", "http_proxy")
        val output = res.stdout.ifBlank { res.stderr }
        return mapOf(
            "success" to (res.exitCode == 0),
            "exitCode" to res.exitCode,
            "proxy" to if (output == "null") "" else output
        )
    }

    private fun setProxy(value: String): Map<String, Any?> {
        if (value.isBlank()) {
            throw IllegalArgumentException("请输入代理地址")
        }
        val res = exec("settings", "put", "global", "http_proxy", value)
        return mapOf(
            "success" to (res.exitCode == 0),
            "exitCode" to res.exitCode,
            "message" to res.stderr.ifBlank { "已设置代理: $value" }
        )
    }

    private fun clearProxy(): Map<String, Any?> {
        val res = exec("settings", "delete", "global", "http_proxy")
        return mapOf(
            "success" to (res.exitCode == 0),
            "exitCode" to res.exitCode,
            "message" to res.stderr.ifBlank { "已清除代理" }
        )
    }

    private data class ExecResult(
        val exitCode: Int,
        val stdout: String,
        val stderr: String
    )
}
