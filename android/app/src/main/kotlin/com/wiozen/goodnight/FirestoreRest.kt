package com.wiozen.goodnight

import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * Small Firestore REST client for the night-mode service, signed in as the
 * app's user (ID token), so the security rules apply exactly as for the app.
 * The Firestore SDK is avoided on purpose: the Flutter plugin applies its
 * settings to the SDK instance at startup, which fails once native code has
 * used it. Call only from a background thread.
 */
object FirestoreRest {
    private const val TAG = "FirestoreRest"

    class Session(val uid: String, val token: String, val db: String)

    /** The signed-in user, if it is [uid]. */
    fun session(uid: String): Session? {
        val user = FirebaseAuth.getInstance().currentUser ?: return null
        if (user.uid != uid) return null
        val token = Tasks.await(user.getIdToken(false), 20, TimeUnit.SECONDS).token ?: return null
        val project = FirebaseApp.getInstance().options.projectId ?: return null
        return Session(uid, token, "projects/$project/databases/(default)/documents")
    }

    /** Runs a `documents:commit` with [body] (`{"writes": [...]}`). */
    fun commit(s: Session, body: JSONObject): Boolean =
        request(s, "https://firestore.googleapis.com/v1/${s.db}:commit", "POST", body) != null

    /** Reads one document (path relative to the database), or null. */
    fun get(s: Session, path: String): JSONObject? =
        request(s, "https://firestore.googleapis.com/v1/${s.db}/$path", "GET", null)

    private fun request(s: Session, url: String, method: String, body: JSONObject?): JSONObject? {
        val conn = URL(url).openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = method
            conn.setRequestProperty("Authorization", "Bearer ${s.token}")
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000
            if (body != null) {
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.outputStream.use { it.write(body.toString().toByteArray()) }
            }
            val code = conn.responseCode
            if (code !in 200..299) {
                Log.w(TAG, "$method returned $code")
                return null
            }
            JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
        } catch (e: Exception) {
            Log.w(TAG, "$method failed: ${e.message}")
            null
        } finally {
            conn.disconnect()
        }
    }

    fun int(v: Int) = JSONObject().put("integerValue", v.toString())

    fun str(v: String) = JSONObject().put("stringValue", v)
}
