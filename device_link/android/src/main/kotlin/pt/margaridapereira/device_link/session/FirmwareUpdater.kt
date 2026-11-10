package pt.margaridapereira.device_link.session

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.protocol.FirmwareCommands
import pt.margaridapereira.device_link.protocol.FirmwareState
import pt.margaridapereira.device_link.protocol.MessageType
import java.util.zip.CRC32

enum class FirmwareStage { SENDING, WAITING_FOR_LINK, VERIFYING, RESTARTING, DONE, FAILED, CANCELLED }

data class FirmwareProgress(val stage: FirmwareStage, val sent: Int, val total: Int, val detail: String? = null) {
    val finished get() = stage == FirmwareStage.DONE || stage == FirmwareStage.FAILED || stage == FirmwareStage.CANCELLED
}

/**
 * Sends a firmware image to the device (SRS-030 to SRS-033).
 *
 * Stop-and-wait: one chunk at a time, the next sent when FW_STATUS confirms how
 * many bytes the bootloader holds. A missing answer is retried; a lost link
 * pauses the transfer, and on reconnect FW_BEGIN for the same image makes the
 * bootloader report what it kept, so the transfer resumes instead of starting
 * over. The update counts as done only when the device restarts and its HELLO
 * reports the new version; a checksum failure or any other version is a
 * failure, and the device keeps running the old firmware.
 */
class FirmwareUpdater(
    private val image: ByteArray,
    private val version: String,
    private val send: (type: Int, payload: ByteArray) -> Unit,
    private val scope: CoroutineScope,
    private val onProgress: (FirmwareProgress) -> Unit,
    private val chunkSize: Int = FirmwareCommands.MAX_CHUNK,
    private val replyTimeoutMs: Long = 1_500,
    private val maxRetries: Int = 8,
    private val restartTimeoutMs: Long = 30_000,
) {
    private val crc32 = CRC32().apply { update(image) }.value
    private var progress = FirmwareProgress(FirmwareStage.SENDING, 0, image.size)
    private var linkUp = false
    private var lastCommand: (() -> Unit)? = null
    private var retries = 0
    private var timer: Job? = null
    private var reportedPercent = -1

    val finished @Synchronized get() = progress.finished

    init {
        require(chunkSize in 1..FirmwareCommands.MAX_CHUNK)
    }

    @Synchronized
    fun start(linkConnected: Boolean) {
        linkUp = linkConnected
        if (linkUp) begin() else report(FirmwareStage.WAITING_FOR_LINK, "waiting for the device")
    }

    @Synchronized
    fun cancel() {
        if (progress.finished) return
        if (linkUp) send(MessageType.FW_ABORT, ByteArray(0))
        finish(FirmwareStage.CANCELLED, "cancelled, the device keeps its current firmware")
    }

    @Synchronized
    fun onEvent(event: SessionEvent) {
        if (progress.finished) return
        when (event) {
            is SessionEvent.Link -> onLink(event.state)
            is SessionEvent.Message -> when (val m = event.message) {
                is DeviceMessage.FirmwareStatus -> onStatus(m)
                is DeviceMessage.Hello -> if (progress.stage == FirmwareStage.RESTARTING) {
                    if (m.firmware == version) finish(FirmwareStage.DONE, "running $version")
                    else finish(FirmwareStage.FAILED, "the device restarted with ${m.firmware}, not $version")
                }
                else -> Unit
            }
            else -> Unit
        }
    }

    private fun onLink(state: LinkState) {
        val wasUp = linkUp
        linkUp = state == LinkState.CONNECTED
        if (progress.stage == FirmwareStage.RESTARTING) return // the restart drops the link; HELLO decides
        if (linkUp && !wasUp) {
            begin()
        } else if (!linkUp && wasUp) {
            timer?.cancel()
            report(FirmwareStage.WAITING_FOR_LINK, "link lost, will resume")
        }
    }

    private fun onStatus(status: DeviceMessage.FirmwareStatus) {
        retries = 0
        when (status.state) {
            FirmwareState.RECEIVING -> {
                val held = status.received.toInt().coerceIn(0, image.size)
                if (held < image.size) {
                    progress = progress.copy(stage = FirmwareStage.SENDING, sent = held, detail = null)
                    reportThrottled()
                    val count = minOf(chunkSize, image.size - held)
                    command(MessageType.FW_CHUNK, FirmwareCommands.chunk(held, image, held, count))
                } else {
                    report(FirmwareStage.VERIFYING, "checking the image", sent = image.size)
                    command(MessageType.FW_COMMIT, ByteArray(0))
                }
            }
            FirmwareState.INSTALLED -> {
                lastCommand = null
                report(FirmwareStage.RESTARTING, status.detail.ifEmpty { "restarting" }, sent = image.size)
                timer?.cancel()
                timer = scope.launch {
                    delay(restartTimeoutMs)
                    synchronized(this@FirmwareUpdater) {
                        if (!progress.finished) finish(FirmwareStage.FAILED, "the device did not come back after restarting")
                    }
                }
            }
            FirmwareState.REJECTED -> finish(FirmwareStage.FAILED, status.detail.ifEmpty { "rejected by the device" })
            FirmwareState.IDLE, FirmwareState.UNKNOWN -> Unit
        }
    }

    private fun begin() {
        report(FirmwareStage.SENDING, if (progress.sent > 0) "resuming" else null)
        command(MessageType.FW_BEGIN, FirmwareCommands.begin(image.size, crc32, version))
    }

    private fun command(type: Int, payload: ByteArray) {
        val c = { send(type, payload) }
        lastCommand = c
        c()
        armRetry()
    }

    private fun armRetry() {
        timer?.cancel()
        timer = scope.launch {
            delay(replyTimeoutMs)
            synchronized(this@FirmwareUpdater) {
                if (progress.finished || !linkUp || progress.stage == FirmwareStage.RESTARTING) return@launch
                if (++retries > maxRetries) {
                    finish(FirmwareStage.FAILED, "the device stopped answering")
                } else {
                    lastCommand?.invoke()
                    armRetry()
                }
            }
        }
    }

    private fun finish(stage: FirmwareStage, detail: String) {
        timer?.cancel()
        lastCommand = null
        report(stage, detail)
    }

    private fun report(stage: FirmwareStage, detail: String?, sent: Int = progress.sent) {
        progress = FirmwareProgress(stage, sent, image.size, detail)
        onProgress(progress)
    }

    /** Chunks arrive hundreds per second; the UI needs a whole percent at most. */
    private fun reportThrottled() {
        val percent = (progress.sent * 100L / image.size).toInt()
        if (percent != reportedPercent) {
            reportedPercent = percent
            onProgress(progress)
        }
    }
}
