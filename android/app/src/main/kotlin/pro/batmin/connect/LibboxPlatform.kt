package pro.batmin.connect

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterface
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.UnknownHostException

class LibboxPlatform(
    private val vpnService: BatminVpnService
) : PlatformInterface {

    override fun autoDetectInterfaceControl(fd: Int) {
        if (!vpnService.protect(fd)) {
            throw IllegalStateException("VpnService.protect($fd) failed")
        }
    }

    override fun clearDNSCache() {
        VpnLog.add("PlatformInterface.clearDNSCache()")
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        VpnLog.add("PlatformInterface.closeDefaultInterfaceMonitor()")
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int
    ): ConnectionOwner {
        return ConnectionOwner()
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        return object : NetworkInterfaceIterator {
            override fun hasNext(): Boolean = false

            override fun next(): NetworkInterface {
                throw NoSuchElementException("No platform interfaces")
            }
        }
    }

    override fun includeAllNetworks(): Boolean = false

    override fun localDNSTransport(): LocalDNSTransport = AndroidLocalDnsTransport(vpnService)

    override fun openTun(options: TunOptions): Int {
        VpnLog.add(
            "PlatformInterface.openTun(): mtu=${options.mtu}, autoRoute=${options.autoRoute}"
        )

        val builder = vpnService.Builder()
            .setSession("Batmin Connect")
            .setMtu(options.mtu)

        fun addAddresses(iterator: io.nekohasekai.libbox.RoutePrefixIterator) {
            while (iterator.hasNext()) {
                val prefix = iterator.next()
                builder.addAddress(prefix.address(), prefix.prefix())
            }
        }

        fun addRoutes(iterator: io.nekohasekai.libbox.RoutePrefixIterator) {
            while (iterator.hasNext()) {
                val prefix = iterator.next()
                builder.addRoute(prefix.address(), prefix.prefix())
            }
        }

        addAddresses(options.inet4Address)
        addAddresses(options.inet6Address)

        addRoutes(options.inet4RouteAddress)
        addRoutes(options.inet6RouteAddress)

        val dns = options.dnsServerAddress.value
        if (dns.isNotBlank()) {
            builder.addDnsServer(dns)
        }

        val tun = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null")

        val fd = tun.detachFd()
        VpnLog.add("Android TUN established, fd=$fd")
        return fd
    }

    override fun readWIFIState(): WIFIState {
        return WIFIState("", "")
    }

    override fun sendNotification(notification: Notification) {
        VpnLog.add("libbox notification received")
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        VpnLog.add("PlatformInterface.startDefaultInterfaceMonitor()")
    }

    override fun systemCertificates(): StringIterator {
        return object : StringIterator {
            override fun hasNext(): Boolean = false
            override fun len(): Int = 0
            override fun next(): String {
                throw NoSuchElementException("No custom system certificates")
            }
        }
    }

    override fun underNetworkExtension(): Boolean = false

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun useProcFS(): Boolean = true
}

/**
 * Resolves names on an underlying Android network instead of feeding DNS back
 * into the VPN TUN. Raw DNS exchange is deliberately disabled: the lookup API
 * works on every Android version supported by the application and is all
 * libbox needs when [raw] returns false.
 */
private class AndroidLocalDnsTransport(context: Context) : LocalDNSTransport {
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    override fun raw(): Boolean = false

    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        throw UnsupportedOperationException("Raw DNS exchange is not supported")
    }

    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        try {
            val addresses = underlyingNetwork().getAllByName(domain).filter { address ->
                when {
                    network.endsWith("4") -> address is Inet4Address
                    network.endsWith("6") -> address is Inet6Address
                    else -> true
                }
            }

            if (addresses.isEmpty()) {
                ctx.errorCode(RCODE_NXDOMAIN)
            } else {
                ctx.success(addresses.mapNotNull { it.hostAddress }.joinToString("\n"))
            }
        } catch (_: UnknownHostException) {
            ctx.errorCode(RCODE_NXDOMAIN)
        }
    }

    private fun underlyingNetwork(): Network {
        return connectivityManager.allNetworks.firstOrNull { network ->
            connectivityManager.getNetworkCapabilities(network)?.let { capabilities ->
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            } == true
        } ?: throw IllegalStateException("No underlying network is available for DNS")
    }

    private companion object {
        const val RCODE_NXDOMAIN = 3
    }
}
