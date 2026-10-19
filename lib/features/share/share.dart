import 'package:cloud_firestore/cloud_firestore.dart';

/// Watch together: one partner shares their phone screen (and its sound) with
/// the other. Either can start it: the sharer offers ("Share my screen"), or
/// the viewer asks ("Ask to see"). The sharer always confirms with Android's
/// own screen-capture dialog.
///
/// `pairs/{pairId}/shares/{id}` doubles as the WebRTC signalling channel: the
/// sharer writes the offer and its ICE candidates, the viewer the answer and
/// theirs.
enum ShareStatus {
  /// The viewer asked to see the sharer's screen; waiting for the sharer.
  asked,

  /// The sharer is capturing and has written an offer; waiting for the viewer.
  offered,

  /// The viewer answered; the screen is on its way.
  live,

  /// Either of them stopped it.
  ended,

  /// The other person said not now.
  declined,
}

/// An invite or a request is only answered for this long.
const shareInviteTtl = Duration(minutes: 2);

/// Old share docs are tidied away after this.
const shareKeepFor = Duration(days: 1);

/// The reactions the viewer can send; they float up on both phones.
const shareReactions = ['❤️', '😂', '😮', '😴', '🍿'];

/// Used when the relay (Cloud Function) is not reachable. Works on the same
/// wifi and on many home networks, but not always on mobile data.
const fallbackIceServers = [
  {
    'urls': ['stun:stun.l.google.com:19302', 'stun:stun.cloudflare.com:3478'],
  },
];

class IceCandidate {
  const IceCandidate(this.candidate, this.sdpMid, this.sdpMLineIndex);

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  Map<String, Object?> toMap() => {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };

  static IceCandidate? fromMap(Object? m) {
    if (m is! Map) return null;
    final c = m['candidate'];
    if (c is! String || c.isEmpty) return null;
    return IceCandidate(
      c,
      m['sdpMid'] as String?,
      (m['sdpMLineIndex'] as num?)?.toInt(),
    );
  }
}

class Share {
  const Share({
    required this.id,
    required this.sharer,
    required this.viewer,
    required this.by,
    required this.status,
    required this.createdAt,
    this.offer,
    this.answer,
    this.sharerIce = const [],
    this.viewerIce = const [],
  });

  final String id;
  final String sharer;
  final String viewer;

  /// Who started it: the sharer (an invite) or the viewer (a request).
  final String by;
  final ShareStatus status;
  final DateTime createdAt;

  /// Session descriptions as `{sdp, type}`.
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;
  final List<IceCandidate> sharerIce;
  final List<IceCandidate> viewerIce;

  bool get askedByViewer => by == viewer;

  bool involves(String uid) => sharer == uid || viewer == uid;

  static ShareStatus statusFrom(Object? s) => ShareStatus.values.firstWhere(
    (v) => v.name == s,
    orElse: () => ShareStatus.ended,
  );

  static List<IceCandidate> _ice(Object? l) => l is List
      ? l.map(IceCandidate.fromMap).whereType<IceCandidate>().toList()
      : const [];

  factory Share.fromMap(String id, Map<String, dynamic> d) => Share(
    id: id,
    sharer: d['sharer'] as String? ?? '',
    viewer: d['viewer'] as String? ?? '',
    by: d['by'] as String? ?? '',
    status: statusFrom(d['status']),
    createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    offer: (d['offer'] as Map?)?.cast<String, dynamic>(),
    answer: (d['answer'] as Map?)?.cast<String, dynamic>(),
    sharerIce: _ice(d['sharerIce']),
    viewerIce: _ice(d['viewerIce']),
  );

  factory Share.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Share.fromMap(doc.id, doc.data() ?? const {});
}

bool isFresh(Share s, DateTime now) =>
    now.difference(s.createdAt) < shareInviteTtl;

/// The newest invite or request waiting for [uid] to answer, if any. [all] is
/// newest-first; only the newest share counts, so an old invite never pops
/// up after a newer session.
Share? incomingPrompt(
  List<Share> all,
  String uid,
  DateTime now, {
  Set<String> dismissed = const {},
}) {
  final s = all.where((s) => s.involves(uid)).firstOrNull;
  if (s == null || dismissed.contains(s.id) || !isFresh(s, now)) return null;
  // Your partner asks to see your screen.
  if (s.status == ShareStatus.asked && s.sharer == uid && s.by != uid) return s;
  // Your partner offers to show you theirs.
  if (s.status == ShareStatus.offered && s.viewer == uid && s.by != uid) {
    return s;
  }
  return null;
}

/// Your shares that are old enough to delete.
List<Share> expiredShares(List<Share> all, String uid, DateTime now) => all
    .where((s) => s.involves(uid) && now.difference(s.createdAt) > shareKeepFor)
    .toList();

/// The relay's answer from the `shareIceServers` function: a list of servers,
/// or one server object (Cloudflare has used both). Falls back to STUN.
List<Map<String, dynamic>> iceServersFrom(Object? data) {
  Object? servers = data is Map ? data['iceServers'] : data;
  if (servers is Map) servers = [servers];
  if (servers is! List) return _fallback();
  final out = <Map<String, dynamic>>[];
  for (final s in servers) {
    if (s is! Map || s['urls'] == null) continue;
    out.add({
      'urls': s['urls'],
      if (s['username'] != null) 'username': s['username'],
      if (s['credential'] != null) 'credential': s['credential'],
    });
  }
  return out.isEmpty ? _fallback() : out;
}

List<Map<String, dynamic>> _fallback() =>
    fallbackIceServers.map((m) => Map<String, dynamic>.from(m)).toList();

/// Lets Opus carry music, not just a voice: asks for a higher bitrate in the
/// session description (the other side sends up to what we ask for).
String boostOpus(String sdp) {
  if (sdp.contains('maxaveragebitrate')) return sdp;
  return sdp.replaceAll(
    'useinbandfec=1',
    'useinbandfec=1;maxaveragebitrate=96000',
  );
}

/// "4:05" or "1:02:09".
String elapsedLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
