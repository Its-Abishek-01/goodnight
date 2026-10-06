// OPTIONAL push alerts. The app works without this; deploying it needs the
// Firebase Blaze (pay-as-you-go) plan. See docs/PUSH.md.
const {
  onDocumentWritten,
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

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
  await admin.messaging().send({ token, notification: { title, body } });
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
