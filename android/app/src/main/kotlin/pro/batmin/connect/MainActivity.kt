package pro.batmin.connect

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "pro.batmin.connect/vpn"
    private val vpnPermissionRequestCode = 4601
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> prepareVpn(result)
                    "start" -> startVpn(call.argument<String>("profileJson").orEmpty(), result)
                    "stop" -> stopVpn(result)
                    "status" -> result.success(BatminVpnService.currentState.name.lowercase())
                    "statusDetails" -> result.success(mapOf(
                        "state" to BatminVpnService.currentState.name.lowercase(),
                        "message" to BatminVpnService.currentMessage,
                        "engineAvailable" to BatminVpnService.engineAvailable,
                    ))
                    "logs" -> result.success(VpnLog.snapshot())
                    else -> result.notImplemented()
                }
            }
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        startActivityForResult(intent, vpnPermissionRequestCode)
    }

    private fun startVpn(profileJson: String, result: MethodChannel.Result) {
        if (profileJson.isBlank()) {
            result.error("EMPTY_PROFILE", "Hysteria2 profile is empty", null)
            return
        }
        if (VpnService.prepare(this) != null) {
            result.error("VPN_PERMISSION_REQUIRED", "VPN permission has not been granted", null)
            return
        }
        val intent = Intent(this, BatminVpnService::class.java).apply {
            action = BatminVpnService.ACTION_START
            putExtra(BatminVpnService.EXTRA_PROFILE_JSON, profileJson)
        }
        ContextCompat.startForegroundService(this, intent)
        result.success(null)
    }

    private fun stopVpn(result: MethodChannel.Result) {
        val intent = Intent(this, BatminVpnService::class.java).apply {
            action = BatminVpnService.ACTION_STOP
        }
        startService(intent)
        result.success(null)
    }

    @Deprecated("Deprecated in Android SDK but retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnPermissionRequestCode) {
            pendingPermissionResult?.success(resultCode == Activity.RESULT_OK)
            pendingPermissionResult = null
        }
    }
}
