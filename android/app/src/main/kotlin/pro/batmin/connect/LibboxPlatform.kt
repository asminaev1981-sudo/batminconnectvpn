package pro.batmin.connect

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
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
    private val connectivityManager =
        vpnService.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    override fun autoDetectInterfaceControl(fd: Int) {
        if (!vpnService.protect(fd)) {
            throw IllegalStateException("VpnService.protect($fd) failed")
        }
    }

    override fun clearDNSCache() {
        VpnLog.add("PlatformInterface.clearDNSCache()")
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        VpnLog.add("PlatformInterface.closeDefaultInterfaceMonitor(): disabled for compatibility")
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
        val interfaces = connectivityManager.allNetworks.mapNotNull { network ->
            val capabilities = connectivityManager.getNetworkCapabilities(network)
                ?: return@mapNotNull null
            if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) {
                return@mapNotNull null
            }
            val link = connectivityManager.getLinkProperties(network)
                ?: return@mapNotNull null
            val interfaceName = link.interfaceName ?: return@mapNotNull null
            val systemInterface = runCatching {
                java.net.NetworkInterface.getByName(interfaceName)
            }.getOrNull() ?: return@mapNotNull null

            NetworkInterface().apply {
                name = interfaceName
                index = systemInterface.index
                mtu = link.mtu.takeIf { it > 0 } ?: systemInterface.mtu
                // libbox parses these values as netip.Prefix, not bare IPs.
                addresses = StringListIterator(link.linkAddresses.map { it.toString() })
            }
        }
        return object : NetworkInterfaceIterator {
            private var position = 0
            override fun hasNext(): Boolean = position < interfaces.size
            override fun next(): NetworkInterface = interfaces[position++]
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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

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

        if (options.autoRoute) {
            // Android 13 introduced IpPrefix/excludeRoute support. On older
            // releases libbox supplies the already-expanded route ranges
            // instead; reading inet*RouteAddress there leaves the VPN without
            // a default route even though the TUN itself is established.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                addRoutes(options.inet4RouteAddress)
                addRoutes(options.inet6RouteAddress)
            } else {
                addRoutes(options.inet4RouteRange)
                addRoutes(options.inet6RouteRange)
            }
        }

        underlyingNetwork()?.let { network ->
            builder.setUnderlyingNetworks(arrayOf(network))
            VpnLog.add("Android TUN underlying network selected")
        }

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
        VpnLog.add("PlatformInterface.startDefaultInterfaceMonitor(): disabled for compatibility")
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

    // Android 10+ restricts /proc network inspection. libbox must use the
    // PlatformInterface inventory above, otherwise it reports
    // "no available network interface" after receiving a TUN packet.
    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    private fun underlyingNetwork(): Network? {
        return connectivityManager.allNetworks
            .filter { network ->
                connectivityManager.getNetworkCapabilities(network)?.let { capabilities ->
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                } == true
            }
            .maxByOrNull { network ->
                val capabilities = connectivityManager.getNetworkCapabilities(network)!!
                when {
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) -> 2
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) -> 1
                    else -> 0
                }
            }
    }

}

private class StringListIterator(private val values: List<String>) : StringIterator {
    private var position = 0
    override fun hasNext(): Boolean = position < values.size
    override fun len(): Int = values.size
    override fun next(): String = values[position++]
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
