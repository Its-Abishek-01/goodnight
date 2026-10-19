package com.wiozen.goodnight

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Asking the partner for extra minutes from the block screen. The request is
 * a pairs/{pairId}/timeRequests/{id} doc; the partner answers in the app and
 * the service polls for the answer, so it works while GoodNight is closed.
 */
object TimeRequests {
    private const val TAG = "TimeRequests"
    private const val POLL_MS = 15_000L

    private val busy = AtomicBoolean(false)
    @Volatile private var lastPollAt = 0L

    /** Sends a request for [minutes]; [done] gets whether it was sent (main thread not guaranteed). */
    fun ask(store: BlockerStore, nightKey: String, minutes: Int, done: (Boolean) -> Unit) {
        val pair = store.loadPair() ?: return done(false)
        val now = System.currentTimeMillis()
        if (!TimeRequest.canAsk(store.loadRequest(), nightKey, now)) return done(false)
        val id = UUID.randomUUID().toString().replace("-", "").take(20)
        NightReporter.executor.execute {
            var ok = false
            try {
                val s = FirestoreRest.session(pair.uid)
                if (s != null) {
                    val fields = JSONObject()
                        .put("from", FirestoreRest.str(pair.uid))
                        .put("minutes", FirestoreRest.int(minutes))
                        .put("nightKey", FirestoreRest.str(nightKey))
                        .put("status", FirestoreRest.str("pending"))
                    val write = JSONObject()
                        .put(
                            "update",
                            JSONObject()
                                .put("name", "${s.db}/pairs/${pair.pairId}/timeRequests/$id")
                                .put("fields", fields),
                        )
                        .put("currentDocument", JSONObject().put("exists", false))
                        .put(
                            "updateTransforms",
                            JSONArray().put(
                                JSONObject().put("fieldPath", "createdAt").put("setToServerValue", "REQUEST_TIME"),
                            ),
                        )
                    ok = FirestoreRest.commit(s, JSONObject().put("writes", JSONArray().put(write)))
                }
            } catch (e: Exception) {
                Log.w(TAG, "ask failed: ${e.message}")
            }
            if (ok) store.saveRequest(TimeRequest.asked(store.loadRequest(), id, minutes, nightKey, now))
            done(ok)
        }
    }

    /**
     * Checks a pending request at most every [POLL_MS]. [decided] gets
     * (approved, minutes) once the partner has answered.
     */
    fun poll(store: BlockerStore, decided: (Boolean, Int) -> Unit) {
        val req = store.loadRequest()
        val now = System.currentTimeMillis()
        if (req.id.isEmpty()) return
        if (TimeRequest.expired(req, now)) {
            store.saveRequest(req.copy(id = ""))
            return
        }
        if (now - lastPollAt < POLL_MS || !busy.compareAndSet(false, true)) return
        lastPollAt = now
        val pair = store.loadPair() ?: return busy.set(false)
        NightReporter.executor.execute {
            try {
                val s = FirestoreRest.session(pair.uid) ?: return@execute
                val doc = FirestoreRest.get(s, "pairs/${pair.pairId}/timeRequests/${req.id}") ?: return@execute
                val status = doc.optJSONObject("fields")?.optJSONObject("status")?.optString("stringValue")
                if (status == "approved" || status == "declined") {
                    store.saveRequest(req.copy(id = ""))
                    decided(status == "approved", req.minutes)
                }
            } catch (e: Exception) {
                Log.w(TAG, "poll failed: ${e.message}")
            } finally {
                busy.set(false)
            }
        }
    }
}
