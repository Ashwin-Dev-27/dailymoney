package com.dailymoney.app

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypted storage for detections captured by [MoneyNotificationListener].
 *
 * Queue and dedupe data are AES-GCM encrypted with a key that never leaves the
 * Android Keystore. The plaintext preferences written by 1.3.1 are migrated on
 * first use and removed, so an upgrade does not leave payment snippets readable.
 *
 * If the Keystore is unavailable the queue fails closed: the detection is
 * dropped rather than written as plaintext.
 */
object SecureCaptureQueue {
    private const val TAG = "SecureCaptureQueue"

    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val LEGACY_QUEUE_KEY = "flutter.dm.capture.queue.v1"
    private const val LEGACY_RECENT_KEY = "flutter.dm.capture.recent.v1"

    private const val SECURE_PREFS = "dm_capture_secure"
    private const val QUEUE_KEY = "queue.v1"
    private const val RECENT_KEY = "recent.v1"

    private const val KEY_ALIAS = "dm.capture.queue.key.v1"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_TAG_BITS = 128
    private const val IV_BYTES = 12
    private const val MAX_QUEUE = 20
    private const val MAX_RECENT = 40
    private const val DEDUPE_WINDOW_MS = 10 * 60 * 1000L

    data class ReadResult(val json: String, val error: String?)

    /** Adds a detection to the front of the encrypted queue. */
    @Synchronized
    fun append(context: Context, detectionJson: String) {
        val prefs = securePrefs(context)
        migrateLegacy(context, prefs)
        try {
            val existing = readArray(prefs, QUEUE_KEY)
            val next = JSONArray()
            next.put(JSONObject(detectionJson))
            for (i in 0 until minOf(existing.length(), MAX_QUEUE - 1)) {
                next.put(existing.opt(i))
            }
            writeEncrypted(prefs, QUEUE_KEY, next.toString())
        } catch (e: Exception) {
            // No plaintext fallback: missing one pending detection is safer than
            // leaving payment text readable on disk.
            Log.e(TAG, "Could not store detection securely", e)
        }
    }

    /**
     * Returns true when [signature] was seen within the dedupe window. The
     * signature itself is hashed before it is stored.
     */
    @Synchronized
    fun isDuplicate(context: Context, signature: String, now: Long): Boolean {
        val prefs = securePrefs(context)
        migrateLegacy(context, prefs)
        val hashed = hashSignature(signature)
        return try {
            val recent = readObject(prefs, RECENT_KEY)
            val last = recent.optLong(hashed, 0)
            val duplicate = last > 0 && now - last < DEDUPE_WINDOW_MS

            recent.put(hashed, now)
            if (recent.length() > MAX_RECENT) {
                val oldest = recent.keys().asSequence().toList()
                    .sortedBy { recent.optLong(it, 0) }
                for (key in oldest.take(recent.length() - MAX_RECENT)) {
                    recent.remove(key)
                }
            }
            writeEncrypted(prefs, RECENT_KEY, recent.toString())
            duplicate
        } catch (e: Exception) {
            Log.e(TAG, "Could not read dedupe state securely", e)
            false
        }
    }

    /**
     * Returns the decrypted queue and removes it. On any decryption failure the
     * queue is left in place so a later retry can still recover it.
     */
    @Synchronized
    fun readAndClear(context: Context): ReadResult {
        val prefs = securePrefs(context)
        migrateLegacy(context, prefs)
        val stored = prefs.getString(QUEUE_KEY, null)
            ?: return ReadResult("[]", null)

        val raw = try {
            decrypt(stored)
        } catch (e: Exception) {
            Log.e(TAG, "Could not decrypt the pending detection queue", e)
            return ReadResult("[]", "decrypt_failed")
        }

        try {
            JSONArray(raw)
        } catch (e: Exception) {
            prefs.edit().remove(QUEUE_KEY).commit()
            return ReadResult("[]", "corrupt_queue")
        }

        prefs.edit().remove(QUEUE_KEY).commit()
        return ReadResult(raw, null)
    }

    /** Drops pending detections without importing them. */
    @Synchronized
    fun clear(context: Context) {
        securePrefs(context).edit().remove(QUEUE_KEY).commit()
    }

    // ── Legacy migration ──────────────────────────────────────

    private fun migrateLegacy(context: Context, secure: SharedPreferences) {
        val legacy = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val legacyQueue = legacy.getString(LEGACY_QUEUE_KEY, null)
        if (legacyQueue != null) {
            try {
                val incoming = JSONArray(legacyQueue)
                val current = readArray(secure, QUEUE_KEY)
                val seen = HashSet<String>()
                val merged = JSONArray()

                for (i in 0 until current.length()) {
                    val item = current.optJSONObject(i) ?: continue
                    val id = item.optString("id")
                    if (id.isNotEmpty()) seen.add(id)
                    merged.put(item)
                }
                for (i in 0 until incoming.length()) {
                    val item = incoming.optJSONObject(i) ?: continue
                    val id = item.optString("id")
                    if (id.isNotEmpty() && !seen.add(id)) continue
                    merged.put(item)
                    if (merged.length() >= MAX_QUEUE) break
                }
                writeEncrypted(secure, QUEUE_KEY, merged.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Could not migrate the legacy detection queue", e)
            }
            // Remove plaintext whether or not parsing succeeded: a broken queue
            // cannot be shown, and leaving it readable defeats the migration.
            legacy.edit().remove(LEGACY_QUEUE_KEY).commit()
        }

        val legacyRecent = legacy.getString(LEGACY_RECENT_KEY, null)
        if (legacyRecent != null) {
            try {
                val old = JSONObject(legacyRecent)
                val current = readObject(secure, RECENT_KEY)
                for (key in old.keys()) {
                    val hashed = hashSignature(key)
                    val last = old.optLong(key, 0)
                    if (last > current.optLong(hashed, 0)) {
                        current.put(hashed, last)
                    }
                }
                writeEncrypted(secure, RECENT_KEY, current.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Could not migrate legacy dedupe state", e)
            }
            legacy.edit().remove(LEGACY_RECENT_KEY).commit()
        }
    }

    // ── Storage helpers ───────────────────────────────────────

    private fun securePrefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(SECURE_PREFS, Context.MODE_PRIVATE)

    private fun readArray(prefs: SharedPreferences, key: String): JSONArray {
        val raw = prefs.getString(key, null) ?: return JSONArray()
        return try {
            JSONArray(decrypt(raw))
        } catch (e: Exception) {
            throw e
        }
    }

    private fun readObject(prefs: SharedPreferences, key: String): JSONObject {
        val raw = prefs.getString(key, null) ?: return JSONObject()
        return JSONObject(decrypt(raw))
    }

    private fun writeEncrypted(prefs: SharedPreferences, key: String, json: String) {
        // commit() so a detection is not lost if the process is killed after the
        // listener returns.
        if (!prefs.edit().putString(key, encrypt(json)).commit()) {
            throw IllegalStateException("Could not persist $key")
        }
    }

    private fun hashSignature(signature: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(signature.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    // ── Keystore crypto ───────────────────────────────────────

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) return existing.secretKey

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE,
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val iv = cipher.iv
        val cipherText = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        val combined = ByteArray(iv.size + cipherText.size)
        System.arraycopy(iv, 0, combined, 0, iv.size)
        System.arraycopy(cipherText, 0, combined, iv.size, cipherText.size)
        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    private fun decrypt(stored: String): String {
        val bytes = Base64.decode(stored, Base64.NO_WRAP)
        if (bytes.size <= IV_BYTES) {
            throw IllegalArgumentException("Encrypted queue value is too short")
        }
        val iv = bytes.copyOfRange(0, IV_BYTES)
        val cipherText = bytes.copyOfRange(IV_BYTES, bytes.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            key(),
            GCMParameterSpec(GCM_TAG_BITS, iv),
        )
        return String(cipher.doFinal(cipherText), Charsets.UTF_8)
    }
}
