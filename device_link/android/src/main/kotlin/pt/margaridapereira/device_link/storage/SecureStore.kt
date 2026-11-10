package pt.margaridapereira.device_link.storage

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.io.IOException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypted file store for patient data (SRS-020, HAZ-007).
 *
 * Each file is sealed with AES-256-GCM. The key is generated inside the Android
 * Keystore and never leaves it, so the files are unreadable if copied off the
 * device, and GCM's tag detects any tampering.
 *
 * File layout: [format version: 1 byte][IV: 12 bytes][ciphertext + 16-byte tag]
 */
class SecureStore(private val dir: File, private val key: () -> SecretKey) {
    companion object {
        private const val FORMAT = 1
        private const val IV_SIZE = 12
        private const val TAG_BITS = 128
        private val NAME = Regex("[A-Za-z0-9_.-]{1,100}")

        /** Key held in the Android Keystore, created on first use. */
        fun keystoreKey(alias: String = "pulsebridge_data"): SecretKey {
            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
            return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
                init(
                    KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build()
                )
                generateKey()
            }
        }
    }

    fun write(name: String, data: ByteArray) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val iv = cipher.iv
        check(iv.size == IV_SIZE) { "unexpected IV size ${iv.size}" }
        val sealed = cipher.doFinal(data)

        dir.mkdirs()
        val tmp = File(dir, "${checked(name)}.tmp")
        tmp.outputStream().use { out ->
            out.write(FORMAT)
            out.write(iv)
            out.write(sealed)
        }
        // Rename is atomic, so a crash never leaves a half-written file behind.
        if (!tmp.renameTo(File(dir, name))) {
            tmp.delete()
            throw IOException("could not save $name")
        }
    }

    /** Returns null if the file does not exist; throws if it was tampered with. */
    fun read(name: String): ByteArray? {
        val file = File(dir, checked(name))
        if (!file.exists()) return null
        val bytes = file.readBytes()
        require(bytes.size > 1 + IV_SIZE && bytes[0].toInt() == FORMAT) { "$name: unknown format" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, bytes, 1, IV_SIZE))
        }
        return cipher.doFinal(bytes, 1 + IV_SIZE, bytes.size - 1 - IV_SIZE)
    }

    fun list(prefix: String = ""): List<String> =
        dir.listFiles()?.map { it.name }?.filter { it.startsWith(prefix) && !it.endsWith(".tmp") }?.sorted() ?: emptyList()

    fun delete(name: String): Boolean = File(dir, checked(name)).delete()

    private fun checked(name: String): String {
        require(NAME.matches(name)) { "invalid file name: $name" }
        return name
    }
}
