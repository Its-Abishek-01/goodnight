package com.wiozen.goodnight

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Sends tonight's night-mode numbers to the shared night log as they happen,
 * so the partner sees them (and gets a push) while GoodNight is closed.
 * Writes go through [FirestoreRest].
 */
object NightReporter {
    private const val TAG = "NightReporter"
    private const val RETRY_MS = 60_000L

    /** One background thread for every network call of the service. */
    val executor = Executors.newSingleThreadExecutor()
    private val inFlight = AtomicBoolean(false)
    @Volatile private var lastFailureAt = 0L

    fun report(store: BlockerStore, nightKey: String, usageMinutes: Int, blocks: Int, phoneMinutes: Int) {
        val pair = store.loadPair() ?: return
        if (!NightReport.shouldReport(store.loadReported(), nightKey, usageMinutes, blocks, phoneMinutes)) return
        val now = System.currentTimeMillis()
        if (now - lastFailureAt < RETRY_MS || !inFlight.compareAndSet(false, true)) return
        executor.execute {
            try {
                if (write(pair, nightKey, usageMinutes, blocks, phoneMinutes)) {
                    store.saveReported(Reported(nightKey, usageMinutes, blocks, phoneMinutes))
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

    private fun write(pair: PairRef, nightKey: String, usageMinutes: Int, blocks: Int, phoneMinutes: Int): Boolean {
        val s = FirestoreRest.session(pair.uid) ?: return false
        val me = JSONObject()
            .put("blocks", FirestoreRest.int(blocks))
            .put("usageMinutes", FirestoreRest.int(usageMinutes))
            .put("phoneMinutes", FirestoreRest.int(phoneMinutes))
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
                    .put("name", "${s.db}/pairs/${pair.pairId}/nights/$nightKey")
                    .put("fields", JSONObject().put("players", players)),
            )
            .put(
                "updateMask",
                JSONObject().put(
                    "fieldPaths",
                    JSONArray(listOf("$prefix.blocks", "$prefix.usageMinutes", "$prefix.phoneMinutes")),
                ),
            )
            .put(
                "updateTransforms",
                JSONArray().put(
                    JSONObject().put("fieldPath", "$prefix.usageAt").put("setToServerValue", "REQUEST_TIME"),
                ),
            )
        return FirestoreRest.commit(s, JSONObject().put("writes", JSONArray().put(write)))
    }
}
