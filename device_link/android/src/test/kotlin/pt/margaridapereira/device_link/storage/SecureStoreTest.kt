package pt.margaridapereira.device_link.storage

import java.io.File
import java.nio.file.Files
import javax.crypto.AEADBadTagException
import javax.crypto.KeyGenerator
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull

/** The Android Keystore is not available on the JVM, so these tests use a software AES key. */
class SecureStoreTest {
    private val dir: File = Files.createTempDirectory("securestore").toFile()
    private val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    private val store = SecureStore(dir) { key }

    @AfterTest
    fun cleanUp() {
        dir.deleteRecursively()
    }

    @Test
    fun roundTrips() {
        val data = ByteArray(100_000) { (it % 251).toByte() }
        store.write("session_1.ecg", data)
        assertContentEquals(data, store.read("session_1.ecg"))
    }

    @Test
    fun storesCiphertextNotPlaintext() {
        val secret = "patient: Maria, HR 72".encodeToByteArray()
        store.write("s.json", secret)
        val onDisk = File(dir, "s.json").readBytes()
        assertFalse(onDisk.decodeToString().contains("Maria"))
        assertEquals(1 + 12 + secret.size + 16, onDisk.size)
    }

    @Test
    fun sameDataEncryptsDifferentlyEachTime() {
        store.write("a", byteArrayOf(1, 2, 3))
        store.write("b", byteArrayOf(1, 2, 3))
        assertFalse(File(dir, "a").readBytes().contentEquals(File(dir, "b").readBytes()))
    }

    @Test
    fun detectsTampering() {
        store.write("s.json", "{\"bpm\":72}".encodeToByteArray())
        val file = File(dir, "s.json")
        val bytes = file.readBytes().also { it[it.size - 20] = (it[it.size - 20].toInt() xor 1).toByte() }
        file.writeBytes(bytes)
        assertFailsWith<AEADBadTagException> { store.read("s.json") }
    }

    @Test
    fun wrongKeyCannotRead() {
        store.write("s.json", byteArrayOf(42))
        val otherKey = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        assertFailsWith<AEADBadTagException> { SecureStore(dir) { otherKey }.read("s.json") }
    }

    @Test
    fun listsAndDeletes() {
        store.write("session_2.json", byteArrayOf(1))
        store.write("session_1.json", byteArrayOf(1))
        store.write("settings.json", byteArrayOf(1))
        assertEquals(listOf("session_1.json", "session_2.json"), store.list("session_"))
        store.delete("session_1.json")
        assertEquals(listOf("session_2.json"), store.list("session_"))
        assertNull(store.read("session_1.json"))
    }

    @Test
    fun rejectsPathTraversal() {
        assertFailsWith<IllegalArgumentException> { store.write("../evil", byteArrayOf(1)) }
        assertFailsWith<IllegalArgumentException> { store.read("a/b") }
    }
}
