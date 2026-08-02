package pro.batmin.connect

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CopyOnWriteArrayList

object VpnLog {
    private const val MAX_ENTRIES = 250
    private val entries = CopyOnWriteArrayList<String>()
    private val formatter = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    fun add(message: String) {
        entries.add("${formatter.format(Date())}  $message")
        while (entries.size > MAX_ENTRIES) entries.removeAt(0)
    }

    fun snapshot(): List<String> = entries.toList()
}
