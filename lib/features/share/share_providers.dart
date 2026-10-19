import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import '../profile/profile.dart';
import 'share.dart';
import 'share_channel.dart';
import 'share_repository.dart';

final shareRepositoryProvider = Provider(
  (ref) => ShareRepository(ref.watch(firestoreProvider)),
);

/// Recent shares between the two of you, newest first.
final sharesProvider = StreamProvider<List<Share>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield const [];
    return;
  }
  yield* ref.watch(shareRepositoryProvider).watchRecent(pair.id);
});

enum SharePhase {
  idle,

  /// The viewer asked and waits for the sharer.
  asking,

  /// The sharer is getting the screen ready (Android's dialog, the call).
  starting,

  /// The sharer waits for the viewer to join.
  waiting,

  /// Both agreed; the call is connecting.
  connecting,

  /// The screen is on its way.
  live,
}

enum ShareRole { sharer, viewer }

class ShareReaction {
  ShareReaction(this.emoji, {this.mine = false}) : id = _next++;
  static int _next = 0;

  final String emoji;

  /// Sent from this phone (it floats up here too).
  final bool mine;
  final int id;
}

class ShareSession {
  const ShareSession({
    this.phase = SharePhase.idle,
    this.role,
    this.shareId,
    this.partnerUid = '',
    this.micOn = false,
    this.sound = false,
    this.liveSince,
    this.reaction,
    this.message,
  });

  final SharePhase phase;
  final ShareRole? role;
  final String? shareId;
  final String partnerUid;
  final bool micOn;

  /// The phone's sound is being sent (sharer only).
  final bool sound;
  final DateTime? liveSince;

  /// The latest reaction, to float up on screen.
  final ShareReaction? reaction;

  /// Why the last session ended or did not start, for the Tonight card.
  final String? message;

  bool get active => phase != SharePhase.idle;

  ShareSession copyWith({
    SharePhase? phase,
    String? shareId,
    bool? micOn,
    bool? sound,
    DateTime? liveSince,
    ShareReaction? reaction,
  }) => ShareSession(
    phase: phase ?? this.phase,
    role: role,
    shareId: shareId ?? this.shareId,
    partnerUid: partnerUid,
    micOn: micOn ?? this.micOn,
    sound: sound ?? this.sound,
    liveSince: liveSince ?? this.liveSince,
    reaction: reaction ?? this.reaction,
    message: message,
  );
}

/// Runs one Watch together session on this phone: the WebRTC call, the
/// signalling through the share doc, the mic and the reactions. It lives as
/// long as the app, so sharing carries on while the sharer is in other apps.
class ShareController extends Notifier<ShareSession> {
  RTCPeerConnection? _pc;
  MediaStream? _screen;
  MediaStream? _mic;
  RTCDataChannel? _dc;
  StreamSubscription<Share?>? _sub;
  Timer? _timeout;
  bool _remoteSet = false;
  Future<void> _chain = Future.value();
  int _appliedIce = 0;
  final _pendingIce = <IceCandidate>[];
  final _localIce = <IceCandidate>[];
  String? _pairId;

  /// The partner's screen, on the viewer's phone.
  RTCVideoRenderer? renderer;

  @override
  ShareSession build() {
    ShareNative.setActionHandler((action) {
      if (action == 'stop') stop();
      if (action == 'mic') toggleMic();
    });
    return const ShareSession();
  }

  ShareRepository get _repo => ref.read(shareRepositoryProvider);

  String _name(String uid) {
    final pair = ref.read(pairProvider).value;
    final n = ref.read(peopleProvider)[uid]?.name ?? pair?.nameOf(uid) ?? '';
    return n.isEmpty ? 'your partner' : n;
  }

  ({String pairId, String uid, String partner})? _ids() {
    final pair = ref.read(pairProvider).value;
    final uid = ref.read(uidProvider).value;
    final partner = uid == null ? null : pair?.partnerUid(uid);
    if (pair == null || uid == null || partner == null) return null;
    return (pairId: pair.id, uid: uid, partner: partner);
  }

  /// Share my screen: as an invite, or as the answer to [request].
  Future<void> shareMyScreen({Share? request}) async {
    final ids = _ids();
    if (state.active || ids == null) return;
    _pairId = ids.pairId;
    state = ShareSession(
      phase: SharePhase.starting,
      role: ShareRole.sharer,
      partnerUid: ids.partner,
    );
    try {
      final micOk = await Permission.microphone.request().isGranted;
      if (!await Helper.requestCapturePermission()) {
        // Cancelled Android's dialog.
        if (request != null) {
          await _repo.setStatus(ids.pairId, request.id, ShareStatus.declined);
        }
        await _finish();
        return;
      }
      await ShareNative.startService(_name(ids.partner));
      _screen = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });
      if (micOk) {
        _mic = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
      }
      final sound = micOk && await ShareNative.startSound();
      // Without the mix, the mic track itself carries only the voice: start muted.
      if (!sound) _setTracks(_mic, false);
      await ShareNative.setMic(false);

      final pc = await _newConnection(sharer: true);
      for (final t in _screen!.getVideoTracks()) {
        await pc.addTrack(t, _screen!);
      }
      final mic = _mic;
      if (mic != null) {
        for (final t in mic.getAudioTracks()) {
          await pc.addTrack(t, mic);
        }
      } else {
        // Still offer audio, so the viewer can talk and be heard.
        await pc.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
      }
      _wireChannel(
        await pc.createDataChannel('reactions', RTCDataChannelInit()),
      );
      final offer = await pc.createOffer();
      final local = RTCSessionDescription(
        boostOpus(offer.sdp ?? ''),
        offer.type,
      );
      await pc.setLocalDescription(local);
      final desc = {'sdp': local.sdp, 'type': local.type};
      final String id;
      if (request != null) {
        await _repo.answerRequest(ids.pairId, request.id, desc);
        id = request.id;
      } else {
        id = await _repo.offer(
          pairId: ids.pairId,
          sharer: ids.uid,
          viewer: ids.partner,
          offer: desc,
        );
      }
      state = state.copyWith(
        phase: SharePhase.waiting,
        shareId: id,
        sound: sound,
      );
      await _flushLocalIce();
      _listen(id);
      _startTimeout('${_name(ids.partner)} didn\'t join this time.');
    } catch (_) {
      await _endShare();
      await _finish(message: 'Could not start sharing. Try again.');
    }
  }

  /// Ask to see the partner's screen.
  Future<void> askToSee() async {
    final ids = _ids();
    if (state.active || ids == null) return;
    _pairId = ids.pairId;
    state = ShareSession(
      phase: SharePhase.asking,
      role: ShareRole.viewer,
      partnerUid: ids.partner,
    );
    try {
      final id = await _repo.ask(
        pairId: ids.pairId,
        viewer: ids.uid,
        sharer: ids.partner,
      );
      state = state.copyWith(shareId: id);
      _listen(id);
      _startTimeout('${_name(ids.partner)} didn\'t answer this time.');
    } catch (_) {
      await _finish(message: 'Could not send that. Check your connection.');
    }
  }

  /// Join an invite to watch.
  Future<void> watch(Share share) async {
    final ids = _ids();
    if (state.active || ids == null) return;
    _pairId = ids.pairId;
    state = ShareSession(
      phase: SharePhase.connecting,
      role: ShareRole.viewer,
      partnerUid: share.sharer,
      shareId: share.id,
    );
    _listen(share.id);
    await _join(share);
  }

  Future<void> decline(Share share) async {
    final pairId = ref.read(pairProvider).value?.id;
    if (pairId == null) return;
    try {
      await _repo.setStatus(pairId, share.id, ShareStatus.declined);
    } catch (_) {}
  }

  Future<void> _join(Share share) async {
    final pairId = _pairId!;
    final offer = share.offer;
    if (offer == null) return;
    state = state.copyWith(phase: SharePhase.connecting);
    _timeout?.cancel();
    try {
      final micOk = await Permission.microphone.request().isGranted;
      final r = RTCVideoRenderer();
      await r.initialize();
      renderer = r;
      final pc = await _newConnection(sharer: false);
      pc.onTrack = (e) {
        if (e.track.kind == 'video' && e.streams.isNotEmpty) {
          renderer?.srcObject = e.streams.first;
        }
      };
      pc.onDataChannel = _wireChannel;
      await pc.setRemoteDescription(
        RTCSessionDescription(
          offer['sdp'] as String?,
          offer['type'] as String?,
        ),
      );
      _remoteSet = true;
      // Added after the offer so it reuses the offered audio line.
      if (micOk) {
        final mic = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
        _mic = mic;
        _setTracks(mic, false);
        for (final t in mic.getAudioTracks()) {
          await pc.addTrack(t, mic);
        }
      }
      final answer = await pc.createAnswer();
      final local = RTCSessionDescription(
        boostOpus(answer.sdp ?? ''),
        answer.type,
      );
      await pc.setLocalDescription(local);
      await _repo.join(pairId, share.id, {
        'sdp': local.sdp,
        'type': local.type,
      });
      await _applyIce(share);
      await _flushLocalIce();
    } catch (_) {
      await _endShare();
      await _finish(message: 'Could not connect. Try again.');
    }
  }

  Future<RTCPeerConnection> _newConnection({required bool sharer}) async {
    final pc = await createPeerConnection({
      'iceServers': await _iceServers(),
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    pc.onIceCandidate = (c) {
      final cand = c.candidate;
      if (cand == null || cand.isEmpty) return;
      _localIce.add(IceCandidate(cand, c.sdpMid, c.sdpMLineIndex));
      _flushLocalIce();
    };
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _timeout?.cancel();
          if (state.phase != SharePhase.live) {
            state = state.copyWith(
              phase: SharePhase.live,
              liveSince: DateTime.now(),
            );
          }
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _endShare().then((_) => _finish(message: 'Lost the connection.'));
        default:
          break;
      }
    };
    return pc;
  }

  Future<List<Map<String, dynamic>>> _iceServers() async {
    try {
      final r = await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('shareIceServers')
          .call<Object?>()
          .timeout(const Duration(seconds: 8));
      return iceServersFrom(r.data);
    } catch (_) {
      return iceServersFrom(null);
    }
  }

  Future<void> _flushLocalIce() async {
    final pairId = _pairId;
    final id = state.shareId;
    if (pairId == null || id == null || _localIce.isEmpty) return;
    final batch = List.of(_localIce);
    _localIce.clear();
    final sharer = state.role == ShareRole.sharer;
    for (final c in batch) {
      try {
        await _repo.addIce(pairId, id, sharer: sharer, c: c);
      } catch (_) {}
    }
  }

  void _listen(String id) {
    _sub?.cancel();
    // One snapshot at a time, in order: setting the answer and adding ICE
    // candidates must not overlap.
    _sub = _repo.watch(_pairId!, id).listen((share) {
      _chain = _chain.then((_) => _onShare(share)).catchError((_) {});
    });
  }

  Future<void> _onShare(Share? share) async {
    if (share == null) {
      await _finish();
      return;
    }
    if (share.status == ShareStatus.ended ||
        share.status == ShareStatus.declined) {
      final name = _name(state.partnerUid);
      await _closeCall();
      await _finish(
        message: share.status == ShareStatus.declined
            ? '$name said not now.'
            : null,
      );
      return;
    }
    final pc = _pc;
    if (state.role == ShareRole.sharer) {
      final answer = share.answer;
      if (pc != null && answer != null && !_remoteSet) {
        await pc.setRemoteDescription(
          RTCSessionDescription(
            answer['sdp'] as String?,
            answer['type'] as String?,
          ),
        );
        _remoteSet = true;
        if (state.phase == SharePhase.waiting) {
          state = state.copyWith(phase: SharePhase.connecting);
        }
      }
    } else if (state.phase == SharePhase.asking &&
        share.status == ShareStatus.offered) {
      // We asked, and they are sharing: join straight away.
      await _join(share);
      return;
    }
    await _applyIce(share);
  }

  /// Adds the other side's new ICE candidates, once the remote description is set.
  Future<void> _applyIce(Share share) async {
    final pc = _pc;
    final theirs = state.role == ShareRole.sharer
        ? share.viewerIce
        : share.sharerIce;
    if (theirs.length > _appliedIce) {
      _pendingIce.addAll(theirs.sublist(_appliedIce));
      _appliedIce = theirs.length;
    }
    if (pc == null || !_remoteSet) return;
    final batch = List.of(_pendingIce);
    _pendingIce.clear();
    for (final c in batch) {
      try {
        await pc.addCandidate(
          RTCIceCandidate(c.candidate, c.sdpMid, c.sdpMLineIndex),
        );
      } catch (_) {}
    }
  }

  void _wireChannel(RTCDataChannel ch) {
    _dc = ch;
    ch.onMessage = (m) {
      try {
        final emoji = (jsonDecode(m.text) as Map)['r'] as String?;
        if (emoji == null || !shareReactions.contains(emoji)) return;
        state = state.copyWith(reaction: ShareReaction(emoji));
        if (state.role == ShareRole.sharer) ShareNative.reaction(emoji);
      } catch (_) {}
    };
  }

  Future<void> sendReaction(String emoji) async {
    state = state.copyWith(reaction: ShareReaction(emoji, mine: true));
    try {
      await _dc?.send(RTCDataChannelMessage(jsonEncode({'r': emoji})));
    } catch (_) {}
  }

  Future<void> toggleMic() async {
    if (!state.active) return;
    final on = !state.micOn;
    state = state.copyWith(micOn: on);
    if (state.role == ShareRole.sharer && state.sound) {
      await ShareNative.setMic(on);
    } else {
      _setTracks(_mic, on);
      if (state.role == ShareRole.sharer) await ShareNative.setMic(on);
    }
  }

  void _setTracks(MediaStream? s, bool on) {
    for (final t in s?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = on;
    }
  }

  void _startTimeout(String message) {
    _timeout?.cancel();
    _timeout = Timer(shareInviteTtl, () async {
      if (state.phase == SharePhase.live ||
          state.phase == SharePhase.connecting) {
        return;
      }
      await _endShare();
      await _finish(message: message);
    });
  }

  /// Stop watching or sharing.
  Future<void> stop() async {
    if (!state.active) return;
    await _endShare();
    await _finish();
  }

  /// Marks the share ended so the other phone stops too, and hangs up.
  Future<void> _endShare() async {
    // Stop listening first, so our own "ended" does not come back to us.
    await _sub?.cancel();
    _sub = null;
    final pairId = _pairId;
    final id = state.shareId;
    if (pairId != null && id != null) {
      try {
        await _repo.setStatus(pairId, id, ShareStatus.ended);
      } catch (_) {}
    }
    await _closeCall();
  }

  Future<void> _closeCall() async {
    _timeout?.cancel();
    await _sub?.cancel();
    _sub = null;
    final wasSharer = state.role == ShareRole.sharer;
    try {
      await _dc?.close();
    } catch (_) {}
    _dc = null;
    final pc = _pc;
    _pc = null;
    try {
      await pc?.close();
      await pc?.dispose();
    } catch (_) {}
    for (final s in [_screen, _mic]) {
      for (final t in s?.getTracks() ?? const <MediaStreamTrack>[]) {
        try {
          await t.stop();
        } catch (_) {}
      }
      try {
        await s?.dispose();
      } catch (_) {}
    }
    _screen = null;
    _mic = null;
    final r = renderer;
    renderer = null;
    try {
      r?.srcObject = null;
      await r?.dispose();
    } catch (_) {}
    if (wasSharer) {
      try {
        await ShareNative.stopService();
      } catch (_) {}
    }
    _remoteSet = false;
    _appliedIce = 0;
    _pendingIce.clear();
    _localIce.clear();
  }

  Future<void> _finish({String? message}) async {
    await _closeCall();
    state = ShareSession(message: message);
  }
}

final shareControllerProvider = NotifierProvider<ShareController, ShareSession>(
  ShareController.new,
);

/// An invite or a request from your partner waiting for an answer, shown
/// full-screen by the app gate.
class ShareInbox extends Notifier<Share?> {
  final _handled = <String>{};

  @override
  Share? build() {
    ref.listen(
      sharesProvider,
      (_, next) => _update(next.value),
      fireImmediately: true,
    );
    // Re-check when a session ends, and drop the prompt once one starts.
    ref.listen(
      shareControllerProvider,
      (_, _) => _update(ref.read(sharesProvider).value),
    );
    return null;
  }

  void _update(List<Share>? all) {
    final uid = ref.read(uidProvider).value;
    if (uid == null || all == null) return;
    if (ref.read(shareControllerProvider).active) {
      state = null;
      return;
    }
    state = incomingPrompt(all, uid, DateTime.now(), dismissed: _handled);
  }

  void dismiss() {
    final cur = state;
    if (cur != null) _handled.add(cur.id);
    state = null;
  }
}

final shareInboxProvider = NotifierProvider<ShareInbox, Share?>(ShareInbox.new);

/// Tidies away shares older than a day.
final shareSyncProvider = Provider<void>((ref) {
  ref.listen(sharesProvider, (_, next) async {
    final all = next.value;
    final uid = ref.read(uidProvider).value;
    final pair = ref.read(pairProvider).value;
    if (all == null || uid == null || pair == null) return;
    final repo = ref.read(shareRepositoryProvider);
    for (final old in expiredShares(all, uid, DateTime.now())) {
      try {
        await repo.delete(pair.id, old.id);
      } catch (_) {}
    }
  }, fireImmediately: true);
});
