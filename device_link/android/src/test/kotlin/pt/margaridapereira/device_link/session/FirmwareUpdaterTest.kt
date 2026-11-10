package pt.margaridapereira.device_link.session

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.protocol.FirmwareState
import pt.margaridapereira.device_link.protocol.MessageType
import java.nio.ByteBuffer
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.zip.CRC32
import kotlin.random.Random
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * The device's bootloader, as in the Python simulator: keeps the partial image,
 * answers every command with FW_STATUS, verifies the CRC on commit.
 */
private class FakeBootloader(var running: String = "1.0.0") {
    var updater: FirmwareUpdater? = null
    var dropAnswers = 0           // swallow the next N answers
    var dropLinkAt: Int? = null    // drop the link once this many bytes arrived
    var corrupt = false
    var linkUp = true
    private var size = 0
    private var crc = 0L
    private var version = ""
    private val buffer = java.io.ByteArrayOutputStream()
    val commands = mutableListOf<Int>()

    fun onCommand(type: Int, payload: ByteArray) {
        if (!linkUp) return
        commands += type
        val b = ByteBuffer.wrap(payload)
        val status = when (type) {
            MessageType.FW_BEGIN -> {
                val s = b.int; val c = b.int.toLong() and 0xFFFFFFFFL
                val v = ByteArray(b.get().toInt()).also { b.get(it) }.decodeToString()
                if (s != size || c != crc || v != version) {
                    size = s; crc = c; version = v; buffer.reset()
                }
                status(FirmwareState.RECEIVING, buffer.size())
            }
            MessageType.FW_CHUNK -> {
                val offset = b.int
                if (offset == buffer.size()) buffer.write(payload, 4, payload.size - 4)
                val drop = dropLinkAt
                if (drop != null && buffer.size() >= drop) {
                    dropLinkAt = null
                    linkUp = false
                    updater!!.onEvent(SessionEvent.Link(LinkState.DISCONNECTED, "link lost"))
                    return
                }
                status(FirmwareState.RECEIVING, buffer.size())
            }
            MessageType.FW_COMMIT -> {
                val image = buffer.toByteArray()
                if (corrupt) image[image.size / 2] = (image[image.size / 2].toInt() xor 1).toByte()
                val ok = image.size == size && CRC32().apply { update(image) }.value == crc
                if (ok) {
                    running = version
                    status(FirmwareState.INSTALLED, size, "restarting")
                } else {
                    status(FirmwareState.REJECTED, 0, "checksum mismatch, kept $running")
                }
            }
            MessageType.FW_ABORT -> status(FirmwareState.IDLE, 0)
            else -> return
        }
        if (dropAnswers > 0) {
            dropAnswers--
            return
        }
        updater!!.onEvent(SessionEvent.Message(status))
        if (status.state == FirmwareState.INSTALLED) restart()
    }

    fun reconnect() {
        linkUp = true
        updater!!.onEvent(SessionEvent.Link(LinkState.CONNECTED))
    }

    private fun restart() {
        linkUp = false
        updater!!.onEvent(SessionEvent.Link(LinkState.DISCONNECTED, "device restarting"))
        linkUp = true
        updater!!.onEvent(SessionEvent.Link(LinkState.CONNECTED))
        updater!!.onEvent(SessionEvent.Message(DeviceMessage.Hello("PB-SIM-0001", running, 250)))
    }

    private fun status(state: FirmwareState, received: Int, detail: String = "") =
        DeviceMessage.FirmwareStatus(state, received.toLong(), detail)
}

class FirmwareUpdaterTest {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val progress = LinkedBlockingQueue<FirmwareProgress>()
    private val history = java.util.concurrent.CopyOnWriteArrayList<FirmwareProgress>()
    private val image = Random(3).nextBytes(10_000)

    @AfterTest
    fun tearDown() = scope.cancel()

    private fun run(device: FakeBootloader, version: String = "1.1.0"): FirmwareUpdater {
        // Commands are answered on another thread, as the real link does.
        val queue = LinkedBlockingQueue<Pair<Int, ByteArray>>()
        val worker = Thread {
            while (true) {
                val (type, payload) = try { queue.take() } catch (_: InterruptedException) { return@Thread }
                device.onCommand(type, payload)
            }
        }.apply { isDaemon = true; start() }
        scope.coroutineContext[kotlinx.coroutines.Job]!!.invokeOnCompletion { worker.interrupt() }
        val updater = FirmwareUpdater(image, version, { t, p -> queue += t to p }, scope, { progress += it; history += it },
            chunkSize = 512, replyTimeoutMs = 200, maxRetries = 3, restartTimeoutMs = 2_000)
        device.updater = updater
        updater.start(linkConnected = true)
        return updater
    }

    private fun final(): FirmwareProgress {
        val deadline = System.currentTimeMillis() + 5_000
        while (System.currentTimeMillis() < deadline) {
            val p = progress.poll(100, TimeUnit.MILLISECONDS) ?: continue
            if (p.finished) return p
        }
        fail("the update never finished")
    }

    private fun seen(stage: FirmwareStage) = history.any { it.stage == stage }

    @Test
    fun sendsTheImageAndConfirmsTheNewVersionAfterRestart() {
        val device = FakeBootloader()
        run(device)
        val end = final()
        assertEquals(FirmwareStage.DONE, end.stage, end.detail)
        assertEquals("1.1.0", device.running)
        assertEquals(20, device.commands.count { it == MessageType.FW_CHUNK }, "10 000 bytes in 512-byte chunks")
    }

    @Test
    fun retriesWhenAnAnswerIsLost() {
        val device = FakeBootloader().apply { dropAnswers = 2 }
        run(device)
        assertEquals(FirmwareStage.DONE, final().stage)
    }

    @Test
    fun resumesFromWhatTheDeviceKeptAfterALinkLoss() {
        val device = FakeBootloader().apply { dropLinkAt = 5_120 }
        run(device)
        val deadline = System.currentTimeMillis() + 3_000
        while (device.linkUp && System.currentTimeMillis() < deadline) Thread.sleep(10)
        Thread.sleep(300) // the link stays down a while; nothing is sent meanwhile
        assertEquals(10, device.commands.count { it == MessageType.FW_CHUNK })
        device.reconnect()
        assertEquals(FirmwareStage.DONE, final().stage)
        assertTrue(seen(FirmwareStage.WAITING_FOR_LINK))
        assertEquals(20, device.commands.count { it == MessageType.FW_CHUNK }, "only the missing half is sent again")
    }

    @Test
    fun aCorruptedImageFailsAndTheDeviceKeepsItsFirmware() {
        val device = FakeBootloader().apply { corrupt = true }
        run(device)
        val end = final()
        assertEquals(FirmwareStage.FAILED, end.stage)
        assertTrue(end.detail!!.contains("checksum"))
        assertEquals("1.0.0", device.running)
    }

    @Test
    fun aDeviceThatStopsAnsweringFails() {
        val device = FakeBootloader().apply { dropAnswers = 100 }
        run(device)
        val end = final()
        assertEquals(FirmwareStage.FAILED, end.stage)
        assertEquals("the device stopped answering", end.detail)
    }

    @Test
    fun cancelSendsAbort() {
        val device = FakeBootloader().apply { dropAnswers = 100 }
        val updater = run(device)
        Thread.sleep(50)
        updater.cancel()
        assertEquals(FirmwareStage.CANCELLED, final().stage)
        Thread.sleep(50)
        assertTrue(MessageType.FW_ABORT in device.commands)
    }
}
