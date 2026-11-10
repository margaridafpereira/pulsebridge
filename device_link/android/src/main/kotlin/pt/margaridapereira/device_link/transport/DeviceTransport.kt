package pt.margaridapereira.device_link.transport

import java.io.Closeable
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket

/**
 * A byte stream to the device. The session only sees this interface, so a BLE
 * (GATT notifications) or USB serial link is one more implementation.
 */
interface DeviceTransport : Closeable {
    val description: String

    /** Blocks until connected; throws IOException on failure. */
    fun open()

    /** Reads block for at most the transport's read timeout, then throw SocketTimeoutException. */
    val input: InputStream
    val output: OutputStream
}

class TcpTransport(
    private val host: String,
    private val port: Int,
    private val connectTimeoutMs: Int = 3_000,
    private val readTimeoutMs: Int = 3_000,
) : DeviceTransport {
    private val socket = Socket()

    override val description get() = "tcp://$host:$port"

    override fun open() {
        socket.tcpNoDelay = true
        socket.soTimeout = readTimeoutMs
        socket.connect(InetSocketAddress(host, port), connectTimeoutMs)
    }

    override val input: InputStream get() = socket.getInputStream()
    override val output: OutputStream get() = socket.getOutputStream()

    override fun close() = socket.close()
}
