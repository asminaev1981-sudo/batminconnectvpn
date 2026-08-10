package pro.batmin.connect

import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterface
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState

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

    override fun localDNSTransport(): LocalDNSTransport {
        throw UnsupportedOperationException("Local DNS transport is not enabled")
    }

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
