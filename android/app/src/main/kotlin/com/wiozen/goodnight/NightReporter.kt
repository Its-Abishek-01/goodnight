package com.wiozen.goodnight

import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Sends tonight's night-mode numbers to the shared night log as they happen,
 * so the partner sees them (and gets a push) while GoodNight is closed.
 *
 * It writes through the Firestore REST API with the signed-in user's ID token
 * rather than the Firestore SDK: the Flutter plugin applies its settings to
 * the SDK instance when the app starts, which fails once something else has
 * used that instance. The security rules apply exactly as for the app.
 */
object NightReporter {
    private const val TAG = "NightReporter"
    private const val RETRY_MS = 60_000L

    private val executor = Executors.newSingleThreadExecutor()
    private val inFlight = AtomicBoolean(false)
    @Volatile private var lastFailureAt = 0L

    fun report(store: BlockerStore, nightKey: String, usageMinutes: Int, blocks: Int) {
        val pair = store.loadPair() ?: return
        if (!NightReport.shouldReport(store.loadReported(), nightKey, usageMinutes, blocks)) return
        val now = System.currentTimeMillis()
        if (now - lastFailureAt < RETRY_MS || !inFlight.compareAndSet(false, true)) return
        executor.execute {
            try {
                if (write(pair, nightKey, usageMinutes, blocks)) {
                    store.saveReported(Reported(nightKey, usageMinutes, blocks))
                } else {
                    lastFailureAt = System.currentTimeMillis()
                }
            } catch (e: Exception) {
                Log.w(TAG, "report failed: ${e.message}")
                lastFailureAt = System.currentTimeMillis()
            } finally {
                inFlight.set(false)
            }
        }
    }

    private fun write(pair: PairRef, nightKey: String, usageMinutes: Int, blocks: Int): Boolean {
        val user = FirebaseAuth.getInstance().currentUser ?: return false
        if (user.uid != pair.uid) return false
        val token = Tasks.await(user.getIdToken(false), 20, TimeUnit.SECONDS).token ?: return false
        val project = FirebaseApp.getInstance().options.projectId ?: return false

        val db = "projects/$project/databases/(default)/documents"
        val me = JSONObject()
            .put("blocks", JSONObject().put("integerValue", blocks.toString()))
            .put("usageMinutes", JSONObject().put("integerValue", usageMinutes.toString()))
        val players = JSONObject().put(
            "mapValue",
            JSONObject().put(
                "fields",
                JSONObject().put(pair.uid, JSONObject().put("mapValue", JSONObject().put("fields", me))),
            ),
        )
        val prefix = "players.`${pair.uid}`"
        // Like set(..., merge) on just these fields; usageAt is the server's time.
        val write = JSONObject()
            .put(
                "update",
                JSONObject()
                    .put("name", "$db/pairs/${pair.pairId}/nights/$nightKey")
                    .put("fields", JSONObject().put("players", players)),
            )
            .put("updateMask", JSONObject().put("fieldPaths", JSONArray(listOf("$prefix.blocks", "$prefix.usageMinutes"))))
            .put(
                "updateTransforms",
                JSONArray().put(
                    JSONObject().put("fieldPath", "$prefix.usageAt").put("setToServerValue", "REQUEST_TIME"),
                ),
            )
        val body = JSONObject().put("writes", JSONArray().put(write))

        val conn = URL("https://firestore.googleapis.com/v1/$db:commit").openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000
            conn.doOutput = true
            conn.outputStream.use { it.write(body.toString().toByteArray()) }
            val code = conn.responseCode
            if (code !in 200..299) Log.w(TAG, "write returned $code")
            code in 200..299
        } finally {
            conn.disconnect()
        }
    }
}
