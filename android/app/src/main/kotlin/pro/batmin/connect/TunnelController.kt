package pro.batmin.connect

import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.SetupOptions
import io.nekohasekai.libbox.SystemProxyStatus

import org.json.JSONObject

/**
 * Owns the native VPN engine lifecycle.
 *
 * The service and Flutter bridge are now fully wired. The only missing binary
 * boundary is the libbox AAR/JNI artifact. Until that artifact is placed in
 * android/app/libs, start() fails explicitly instead of reporting a false
 * connected state.
 */
class TunnelController(private val vpnService: BatminVpnService) {

    private var commandServer: CommandServer? = null
    private var libboxSetupDone = false

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
                StartResult(false, "В VPN-профиле отсутствует outbound")
            } else {
                StartResult(true, "VPN-профиль прошёл проверку")
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
        return try {
            ensureLibboxSetup()

            val platform = LibboxPlatform(vpnService)

            val handler = object : CommandServerHandler {
                override fun getSystemProxyStatus(): SystemProxyStatus? = null

                override fun serviceReload() {
                    VpnLog.add("libbox requested serviceReload")
                }

                override fun serviceStop() {
                    VpnLog.add("libbox requested serviceStop")
                }

                override fun setSystemProxyEnabled(enabled: Boolean) {
                    VpnLog.add("System proxy request: $enabled")
                }

                override fun writeDebugMessage(message: String) {
                    VpnLog.add("libbox: $message")
                }
            }

            val server = Libbox.newCommandServer(handler, platform)

            server.start()

            val overrideOptions = OverrideOptions().apply {
                autoRedirect = false
            }

            server.startOrReloadService(profileJson, overrideOptions)

            if (!platform.awaitDefaultInterface(5_000)) {
                throw IllegalStateException(
                    "Android не передал физический сетевой интерфейс в libbox"
                )
            }

            commandServer = server

            VpnLog.add("libbox CommandServer started")
            StartResult(true, "VPN-туннель запущен")
        } catch (e: Exception) {
            VpnLog.add("libbox start failed: ${e.message}")
            commandServer?.runCatching { close() }
            commandServer = null
            StartResult(false, "Ошибка запуска VPN: ${e.message}")
        }
    }

    fun stop() {
        commandServer?.let { server ->
            runCatching { server.closeService() }
                .onFailure { VpnLog.add("closeService: ${it.message}") }

            runCatching { server.close() }
                .onFailure { VpnLog.add("CommandServer.close: ${it.message}") }
        }

        commandServer = null

        VpnLog.add("TunnelController.stop()")
    }

    private fun ensureLibboxSetup() {
        if (libboxSetupDone) return

        val options = SetupOptions().apply {
            basePath = vpnService.filesDir.absolutePath
            workingPath = vpnService.filesDir.absolutePath
            tempPath = vpnService.cacheDir.absolutePath
            fixAndroidStack = true
            commandServerListenPort = 0
            commandServerSecret = ""
            logMaxLines = 500
            debug = true
        }

        Libbox.setup(options)
        libboxSetupDone = true

        VpnLog.add("libbox setup complete: ${Libbox.version()}")
    }

}
