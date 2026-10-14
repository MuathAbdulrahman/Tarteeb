package com.tarteeb.tarteeb

import android.util.Base64
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Password-based encryption for optional financial backups.
 * Key: PBKDF2-HMAC-SHA256 (implemented with javax.crypto.Mac so it works on
 * every supported API level), 256-bit key, random 16-byte salt.
 * Cipher: AES-256-GCM, random 12-byte IV, 128-bit tag, fixed AAD.
 */
object CryptoUtil {
    private const val ITERATIONS = 210_000
    private const val AAD = "tarteeb-finance-v1"

    private fun pbkdf2(password: ByteArray, salt: ByteArray, iterations: Int): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(password, "HmacSHA256"))
        // Single block (32 bytes) is exactly the 256-bit key length.
        mac.update(salt)
        mac.update(byteArrayOf(0, 0, 0, 1))
        var u = mac.doFinal()
        val t = u.copyOf()
        for (i in 1 until iterations) {
            u = mac.doFinal(u)
            for (j in t.indices) t[j] = (t[j].toInt() xor u[j].toInt()).toByte()
        }
        return t
    }

    private fun b64(b: ByteArray): String = Base64.encodeToString(b, Base64.NO_WRAP)
    private fun unb64(s: String): ByteArray = Base64.decode(s, Base64.NO_WRAP)

    fun encrypt(data: ByteArray, password: String): Map<String, Any> {
        val rnd = SecureRandom()
        val salt = ByteArray(16).also { rnd.nextBytes(it) }
        val iv = ByteArray(12).also { rnd.nextBytes(it) }
        val key = SecretKeySpec(pbkdf2(password.toByteArray(Charsets.UTF_8), salt, ITERATIONS), "AES")
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(128, iv))
        c.updateAAD(AAD.toByteArray(Charsets.UTF_8))
        val ct = c.doFinal(data)
        return mapOf(
            "alg" to "AES-256-GCM",
            "kdf" to "PBKDF2-HMAC-SHA256",
            "iterations" to ITERATIONS,
            "aad" to AAD,
            "salt" to b64(salt),
            "iv" to b64(iv),
            "ciphertext" to b64(ct),
        )
    }

    /** Returns null if the password is wrong or the data was modified. */
    fun decrypt(env: Map<*, *>, password: String): ByteArray? {
        return try {
            if (env["alg"] != "AES-256-GCM" || env["kdf"] != "PBKDF2-HMAC-SHA256") return null
            val iterations = (env["iterations"] as Number).toInt()
            if (iterations < 10_000 || iterations > 5_000_000) return null
            val salt = unb64(env["salt"] as String)
            val iv = unb64(env["iv"] as String)
            val ct = unb64(env["ciphertext"] as String)
            val aad = (env["aad"] as? String) ?: AAD
            val key = SecretKeySpec(pbkdf2(password.toByteArray(Charsets.UTF_8), salt, iterations), "AES")
            val c = Cipher.getInstance("AES/GCM/NoPadding")
            c.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
            c.updateAAD(aad.toByteArray(Charsets.UTF_8))
            c.doFinal(ct)
        } catch (e: Exception) {
            null
        }
    }
}
