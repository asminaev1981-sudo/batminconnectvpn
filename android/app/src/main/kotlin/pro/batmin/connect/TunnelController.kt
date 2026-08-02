package pro.batmin.connect

import android.content.Context
import org.json.JSONObject

/**
 * Owns the native VPN engine lifecycle.
 *
 * The service and Flutter bridge are now fully wired. The only missing binary
 * boundary is the libbox AAR/JNI artifact. Until that artifact is placed in
 * android/app/libs, start() fails explicitly instead of reporting a false
 * connected state.
 */
class TunnelController(private val context: Context) {
    data class StartResult(val success: Boolean, val message: String)

    val engineAvailable: Boolean
        get() = LibboxRuntime.probe().available

    fun validateProfile(profileJson: String): StartResult {
        return try {
            val root = JSONObject(profileJson)
            val inbounds = root.optJSONArray("inbounds")
            val outbounds = root.optJSONArray("outbounds")
            if (inbounds == null || inbounds.length() == 0) {
                StartResult(false, "В профиле отсутствует inbound TUN")
            } else if (outbounds == null || outbounds.length() == 0) {
                StartResult(false, "В профиле отсутствует outbound Hysteria2")
            } else {
                StartResult(true, "Профиль Hysteria2 прошёл проверку")
            }
        } catch (error: Exception) {
            StartResult(false, "Некорректный JSON-профиль: ${error.message}")
        }
    }

    fun start(profileJson: String): StartResult {
        val validation = validateProfile(profileJson)
        if (!validation.success) return validation
        val probe = LibboxRuntime.probe()
        VpnLog.add(probe.message)
        if (!probe.available) {
            probe.publicMethods.take(40).forEach { VpnLog.add("libbox API: $it") }
            return StartResult(false, probe.message)
        }

        // At this point the pinned native binary and required API are both
        // present. The next adapter binds Android's VpnService platform
        // callbacks to Libbox.newService(). We still fail closed until that
        // platform interface is installed: no false protected state.
        return StartResult(false, "libbox совместим; требуется Android PlatformInterface адаптер")
    }

    fun stop() {
        VpnLog.add("TunnelController.stop()")
    }
}
