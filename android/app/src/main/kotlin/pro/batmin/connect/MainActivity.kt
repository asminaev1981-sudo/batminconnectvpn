package pro.batmin.connect

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.net.TrafficStats
import android.os.Process
import android.os.SystemClock
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.InetAddress
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "pro.batmin.connect/vpn"
    private val vpnPermissionRequestCode = 4601
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val amneziaWgController: AmneziaWgController by lazy {
        AmneziaWgController(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> prepareVpn(result)
                    "start" -> startVpn(call.argument<String>("profileJson").orEmpty(), result)
                    "stop" -> stopVpn(result)

                    "startAmneziaWg" -> {
                        startAmneziaWg(
                            call.argument<String>("configText").orEmpty(),
                            result
                        )
                    }

                    "stopAmneziaWg" -> stopAmneziaWg(result)

                    "amneziaWgStatus" ->
                        result.success(
                            amneziaWgController.state().name.lowercase()
                        )

                    "telemetry" -> collectTelemetry(
                        call.argument<String>("host") ?: "94.141.98.124",
                        result
                    )

                    "status" -> result.success(BatminVpnService.currentState.name.lowercase())
                    "statusDetails" -> result.success(mapOf(
                        "state" to BatminVpnService.currentState.name.lowercase(),
                        "message" to BatminVpnService.currentMessage,
                        "engineAvailable" to BatminVpnService.engineAvailable,
                    ))

                    "engineProbe" -> {
                        val probe = LibboxRuntime.probe()
                        result.success(
                            mapOf(
                                "available" to probe.available,
                                "message" to probe.message,
                                "className" to (probe.className ?: ""),
                                "methods" to probe.publicMethods,
                            )
                        )
                    }

                    "logs" -> result.success(VpnLog.snapshot())
                    else -> result.notImplemented()
                }
            }
    }

    private fun collectTelemetry(host: String, result: MethodChannel.Result) {
        thread(name = "batmin-telemetry", isDaemon = true) {
            val started = SystemClock.elapsedRealtime()
            val reachable = runCatching {
                InetAddress.getByName(host).isReachable(1200)
            }.getOrDefault(false)
            val elapsed = (SystemClock.elapsedRealtime() - started).toInt()
            val uid = Process.myUid()
            val payload = mapOf(
                "pingMs" to if (reachable) elapsed else -1,
                "rxBytes" to TrafficStats.getUidRxBytes(uid),
                "txBytes" to TrafficStats.getUidTxBytes(uid),
                "timestampMs" to SystemClock.elapsedRealtime(),
            )
            runOnUiThread { result.success(payload) }
        }
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        VpnLog.add("VPN_PERMISSION: prepareVpn called")
        val intent = VpnService.prepare(this)
        VpnLog.add("VPN_PERMISSION: prepare result intent=" + (intent != null))
        if (intent == null) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        VpnLog.add("VPN_PERMISSION: launching Android permission activity")
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

    private fun startAmneziaWg(
        configText: String,
        result: MethodChannel.Result
    ) {
        if (configText.isBlank()) {
            result.error(
                "EMPTY_AWG_CONFIG",
                "AmneziaWG config is empty",
                null
            )
            return
        }

        if (VpnService.prepare(this) != null) {
            result.error(
                "VPN_PERMISSION_REQUIRED",
                "VPN permission has not been granted",
                null
            )
            return
        }

        amneziaWgController
            .start(configText)
            .onSuccess {
                result.success(null)
            }
            .onFailure { error ->
                val cause = generateSequence(error) { it.cause }
                    .joinToString(" <- ") { item ->
                        "${item.javaClass.simpleName}: ${item.message ?: "no message"}"
                    }
                VpnLog.add("AWG start failed: $cause")
                result.error(
                    "AWG_START_FAILED",
                    cause,
                    null
                )
            }
    }

    private fun stopAmneziaWg(
        result: MethodChannel.Result
    ) {
        amneziaWgController
            .stop()
            .onSuccess {
                result.success(null)
            }
            .onFailure { error ->
                VpnLog.add("AWG stop failed: ${error.message}")
                result.error(
                    "AWG_STOP_FAILED",
                    error.message ?: "Unable to stop AmneziaWG",
                    null
                )
            }
    }

    @Deprecated("Deprecated in Android SDK but retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnPermissionRequestCode) {
            VpnLog.add("VPN_PERMISSION: onActivityResult resultCode=$resultCode")
            pendingPermissionResult?.success(resultCode == Activity.RESULT_OK)
            pendingPermissionResult = null
        }
    }
}
