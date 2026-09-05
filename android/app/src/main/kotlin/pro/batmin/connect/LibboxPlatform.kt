package pro.batmin.connect

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
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
import java.util.concurrent.ConcurrentHashMap

class LibboxPlatform(
    private val vpnService: BatminVpnService
) : PlatformInterface {
    private val connectivityManager =
        vpnService.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val interfaceMonitors =
        ConcurrentHashMap<InterfaceUpdateListener, ConnectivityManager.NetworkCallback>()

    override fun autoDetectInterfaceControl(fd: Int) {
        if (!vpnService.protect(fd)) {
            throw IllegalStateException("VpnService.protect($fd) failed")
        }
    }

    override fun clearDNSCache() {
        VpnLog.add("PlatformInterface.clearDNSCache()")
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        interfaceMonitors.remove(listener)?.let { callback ->
            runCatching { connectivityManager.unregisterNetworkCallback(callback) }
        }
        VpnLog.add("PlatformInterface.closeDefaultInterfaceMonitor(): closed")
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
        val interfaces = connectivityManager.allNetworks.mapNotNull(::toLibboxInterface)
        return object : NetworkInterfaceIterator {
            private var index = 0

            override fun hasNext(): Boolean = index < interfaces.size

            override fun next(): NetworkInterface = interfaces[index++]
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
        closeDefaultInterfaceMonitor(listener)
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = notifyDefaultInterface(listener)
            override fun onLost(network: Network) = notifyDefaultInterface(listener)
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) =
                notifyDefaultInterface(listener)
        }
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        interfaceMonitors[listener] = callback
        connectivityManager.registerNetworkCallback(request, callback)
        notifyDefaultInterface(listener)
        VpnLog.add("PlatformInterface.startDefaultInterfaceMonitor(): active")
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

    private fun notifyDefaultInterface(listener: InterfaceUpdateListener) {
        val network = underlyingNetwork() ?: return
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return
        val interfaceName = connectivityManager.getLinkProperties(network)?.interfaceName ?: return
        val systemInterface = runCatching {
            java.net.NetworkInterface.getByName(interfaceName)
        }.getOrNull() ?: return
        listener.updateDefaultInterface(
            interfaceName,
            systemInterface.index,
            !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED),
            false
        )
    }

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

    private fun toLibboxInterface(network: Network): NetworkInterface? {
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return null
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) return null
        val link = connectivityManager.getLinkProperties(network) ?: return null
        val name = link.interfaceName ?: return null
        val systemInterface = runCatching {
            java.net.NetworkInterface.getByName(name)
        }.getOrNull() ?: return null

        return NetworkInterface().apply {
            index = systemInterface.index
            mtu = link.mtu.takeIf { it > 0 } ?: systemInterface.mtu
            this.name = name
            addresses = StringListIterator(link.linkAddresses.map { it.address.hostAddress.orEmpty() })
            flags = (if (systemInterface.isUp) 1 else 0) or
                (if (systemInterface.isLoopback) 4 else 0) or
                (if (systemInterface.isPointToPoint) 8 else 0) or
                (if (systemInterface.supportsMulticast()) 16 else 0)
            type = when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 1
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 2
                else -> 3
            }
            dnsServer = StringListIterator(link.dnsServers.mapNotNull { it.hostAddress })
            metered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
        }
    }
}

private class StringListIterator(private val values: List<String>) : StringIterator {
    private var index = 0
    override fun hasNext(): Boolean = index < values.size
    override fun len(): Int = values.size
    override fun next(): String = values[index++]
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
