package pro.batmin.connect

import android.content.Context
import org.amnezia.awg.backend.GoBackend
import org.amnezia.awg.backend.Tunnel
import org.amnezia.awg.config.Config
import java.io.BufferedReader
import java.io.StringReader

class AmneziaWgController(context: Context) {

    private val backend = GoBackend(context.applicationContext)

    private var currentState: Tunnel.State = Tunnel.State.DOWN

    private val tunnel = object : Tunnel {
        override fun getName(): String = "batmin_awg"

        override fun onStateChange(newState: Tunnel.State) {
            currentState = newState
            VpnLog.add("AWG state changed: $newState")
        }
    }

    @Synchronized
    fun start(configText: String): Result<Unit> {
        return runCatching {
            require(configText.isNotBlank()) {
                "AmneziaWG config is empty"
            }

            VpnLog.add("AWG: parsing configuration")

            val config = Config.parse(
                BufferedReader(StringReader(configText))
            )

            VpnLog.add("AWG: starting tunnel")

            val result = backend.setState(
                tunnel,
                Tunnel.State.UP,
                config
            )

            currentState = result

            if (result != Tunnel.State.UP) {
                error("AWG failed to enter UP state: $result")
            }

            VpnLog.add("AWG: tunnel UP")
        }.onFailure { error ->
            val cause = generateSequence(error) { it.cause }
                .joinToString(" <- ") { item ->
                    "${item.javaClass.simpleName}: ${item.message ?: "no message"}"
                }
            VpnLog.add("AWG failure: $cause")
        }
    }

    @Synchronized
    fun stop(): Result<Unit> {
        return runCatching {
            VpnLog.add("AWG: stopping tunnel")

            val result = backend.setState(
                tunnel,
                Tunnel.State.DOWN,
                null
            )

            currentState = result

            VpnLog.add("AWG: tunnel state after stop: $result")
        }
    }

    fun state(): Tunnel.State {
        return try {
            backend.getState(tunnel).also {
                currentState = it
            }
        } catch (_: Exception) {
            currentState
        }
    }

    fun isRunning(): Boolean =
        state() == Tunnel.State.UP

    fun version(): String =
        try {
            backend.version
        } catch (_: Exception) {
            "unknown"
        }
}
