// OPTIONAL push alerts. The app works without this; deploying it needs the
// Firebase Blaze (pay-as-you-go) plan. See docs/PUSH.md.
const {
  onDocumentWritten,
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

// Next to the Firestore database (Mumbai), where the functions already run.
setGlobalOptions({ region: 'asia-south1' });

admin.initializeApp();
const db = admin.firestore();

async function partnerToken(pairId, actorUid) {
  const pair = (await db.doc(`pairs/${pairId}`).get()).data();
  const partner = (pair?.members || []).find((m) => m !== actorUid);
  if (!partner) return null;
  return (await db.doc(`users/${partner}`).get()).data()?.fcmToken || null;
}

async function push(token, title, body) {
  if (!token) return;
  await admin.messaging().send({
    token,
    notification: { title, body },
    // The app's high-importance channel, so it pops up like a chat message
    // instead of landing quietly in the tray.
    android: {
      priority: 'high',
      notification: { channelId: 'goodnight_general', defaultSound: true },
    },
  });
}

// A partner has snoozed 2 or 3 times: tell the other person.
exports.snoozeAlert = onDocumentWritten('pairs/{pairId}/nights/{key}', async (event) => {
  const before = event.data.before.data()?.players || {};
  const after = event.data.after.data()?.players || {};
  for (const [uid, p] of Object.entries(after)) {
    const was = before[uid]?.snoozes || 0;
    const now = p.snoozes || 0;
    if (now > was && (now === 2 || now === 3) && !p.wokeAt) {
      const name = (await db.doc(`users/${uid}`).get()).data()?.name || 'Your partner';
      await push(
        await partnerToken(event.params.pairId, uid),
        `${name} is still asleep`,
        `They have snoozed ${now} times. Maybe give them a call.`,
      );
    }
  }
});

// Minutes of phone use after the partner's bedtime before you are told, as
// you chose on the Us tab (features/{you}.alertAfter; 0 = off).
const DEFAULT_ALERT_AFTER = 15;

// Phone use after bedtime crossed the minutes the partner chose (alertAfter),
// or night mode stepped in on Instagram/Shorts. The phone's night-mode
// service reports this live (with usageAt) even while the app is closed.
exports.nightModeAlert = onDocumentWritten('pairs/{pairId}/nights/{key}', async (event) => {
  const before = event.data.before.data()?.players || {};
  const after = event.data.after.data()?.players || {};
  for (const [uid, p] of Object.entries(after)) {
    const was = before[uid] || {};
    // Only live reports carry usageAt; the app's catch-up upload on open does not.
    if (!p.usageAt || (was.usageAt && was.usageAt.isEqual(p.usageAt))) continue;
    const pair = (await db.doc(`pairs/${event.params.pairId}`).get()).data();
    const watcher = (pair?.members || []).find((m) => m !== uid);
    if (!watcher) continue;
    const token = (await userDoc(watcher)).fcmToken;
    if (!token) continue;
    const name = (await userDoc(uid)).name || 'Your partner';
    const scrolled = p.usageMinutes || 0;

    if ((p.blocks || 0) > (was.blocks || 0)) {
      await push(
        token,
        `🌙 Night mode paused ${name}'s scrolling`,
        `${scrolled} min on Instagram/Shorts after bedtime tonight.`,
      );
      continue;
    }

    const prefs = (await db.doc(`pairs/${event.params.pairId}/features/${watcher}`).get()).data() || {};
    const limit = typeof prefs.alertAfter === 'number' ? prefs.alertAfter : DEFAULT_ALERT_AFTER;
    if (limit <= 0) continue;
    // Older app versions only report Instagram/Shorts minutes.
    const now = Math.max(p.phoneMinutes || 0, scrolled);
    const then = Math.max(was.phoneMinutes || 0, was.usageMinutes || 0);
    if (then < limit && now >= limit) {
      const detail = scrolled > 0 ? ` (${scrolled} on Instagram/Shorts)` : '';
      await push(
        token,
        `📱 ${name} is still on their phone`,
        `${now} min after bedtime${detail}. Maybe send a love note 💌`,
      );
    }
  }
});

// Someone checked in ("going to sleep") or woke up: a data-only push so the
// partner's "Going to sleep" widget updates while the app is closed. The app
// shows "{name} is going to sleep" itself.
exports.statusAlert = onDocumentWritten('pairs/{pairId}/nights/{key}', async (event) => {
  const before = event.data.before.data()?.players || {};
  const after = event.data.after.data()?.players || {};
  for (const [uid, p] of Object.entries(after)) {
    const was = before[uid] || {};
    let state;
    let at;
    if (p.wokeAt && !was.wokeAt) {
      state = 'up';
      at = p.wokeAt;
    } else if (p.checkedInAt && !(was.checkedInAt && was.checkedInAt.isEqual(p.checkedInAt))) {
      state = 'asleep';
      at = p.checkedInAt;
    } else {
      continue;
    }
    const token = await partnerToken(event.params.pairId, uid);
    if (!token) continue;
    await admin.messaging().send({
      token,
      data: {
        type: 'status',
        state,
        at: at.toDate().toISOString(),
        name: (await userDoc(uid)).name || 'Your partner',
      },
      android: { priority: 'high' },
    });
  }
});

// A new bedtime proposal needs the partner's approval.
exports.proposalAlert = onDocumentWritten('pairs/{pairId}/schedules/{owner}', async (event) => {
  const after = event.data.after.data();
  const before = event.data.before.data();
  const by = after?.proposal?.by;
  if (!by || before?.proposal?.bedtime === after.proposal.bedtime && before?.proposal?.by === by) return;
  const name = (await db.doc(`users/${by}`).get()).data()?.name || 'Your partner';
  await push(await partnerToken(event.params.pairId, by), 'Bedtime to approve', `${name} suggested a bedtime.`);
});

// A coupon was redeemed: it cannot be refused.
exports.couponAlert = onDocumentWritten('pairs/{pairId}/coupons/{id}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!after || after.status !== 'redeemed' || before?.status === 'redeemed') return;
  const name = (await db.doc(`users/${after.holder}`).get()).data()?.name || 'Your partner';
  await push(
    await partnerToken(event.params.pairId, after.holder),
    `${name} used a coupon 💌`,
    `${after.title} - no questions asked.`,
  );
});

async function userDoc(uid) {
  return (await db.doc(`users/${uid}`).get()).data() || {};
}

// A new selfie: a data-only push so the app can refresh the home-screen widget
// even when it is closed. The app builds the notification itself.
exports.selfieAlert = onDocumentCreated('pairs/{pairId}/selfies/{id}', async (event) => {
  const selfie = event.data.data();
  const token = await partnerToken(event.params.pairId, selfie.from);
  if (!token) return;
  const name = (await userDoc(selfie.from)).name || 'Your partner';
  await admin.messaging().send({
    token,
    data: {
      type: 'selfie',
      pairId: event.params.pairId,
      selfieId: event.params.id,
      name,
    },
    android: { priority: 'high' },
  });
});

// The receiver opened the selfie: tell the sender (the read receipt).
exports.selfieSeenAlert = onDocumentUpdated('pairs/{pairId}/selfies/{id}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.seenAt || !after.seenAt) return;
  const pair = (await db.doc(`pairs/${event.params.pairId}`).get()).data();
  const viewer = (pair?.members || []).find((m) => m !== after.from);
  if (!viewer) return;
  const name = (await userDoc(viewer)).name || 'Your partner';
  await push((await userDoc(after.from)).fcmToken, '👀 Seen', `${name} saw your selfie.`);
});

// A sudden love note: show it to the partner right away.
exports.loveNoteAlert = onDocumentCreated('pairs/{pairId}/loveNotes/{id}', async (event) => {
  const note = event.data.data();
  const name = (await userDoc(note.from)).name || 'Your partner';
  await push(
    await partnerToken(event.params.pairId, note.from),
    `💌 ${name}`,
    note.text,
  );
});

// The partner saw the love note: tell the sender (the read receipt).
exports.loveNoteSeenAlert = onDocumentUpdated('pairs/{pairId}/loveNotes/{id}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.seenAt || !after.seenAt) return;
  const pair = (await db.doc(`pairs/${event.params.pairId}`).get()).data();
  const viewer = (pair?.members || []).find((m) => m !== after.from);
  if (!viewer) return;
  const name = (await userDoc(viewer)).name || 'Your partner';
  await push((await userDoc(after.from)).fcmToken, '👀 Seen', `${name} read your love note.`);
});
