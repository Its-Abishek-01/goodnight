import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair.dart';
import '../pairing/pair_providers.dart';
import '../pairing/partner_color.dart';

/// Rules cap profile photos at 200 KB; pictures are picked at 320px so they
/// normally come in far below that.
const profilePhotoMaxBytes = 190000;

/// What you privately call your partner: a pet name and your own photo of
/// them. Stored in `nicknames/{yourUid}`, which only you can read.
class Nickname {
  const Nickname({this.petName, this.photo});

  static const none = Nickname();

  final String? petName;
  final Uint8List? photo;

  factory Nickname.fromMap(Map<String, dynamic>? d) {
    final pet = (d?['petName'] as String?)?.trim();
    return Nickname(
      petName: pet == null || pet.isEmpty ? null : pet,
      photo: (d?['photo'] as Blob?)?.bytes,
    );
  }
}

/// How one person appears on this phone.
class Person {
  const Person({required this.name, required this.color, this.photo});

  final String name;
  final PartnerColor color;
  final Uint8List? photo;
}

/// Your partner shows with the pet name and photo you gave them, falling
/// back to their own name and profile photo. You always show as yourself.
Person resolvePerson({
  required Pair pair,
  required String viewer,
  required String uid,
  required Map<String, Uint8List> photos,
  required Nickname nickname,
}) {
  final isPartner = uid != viewer;
  return Person(
    name: (isPartner ? nickname.petName : null) ?? pair.nameOf(uid),
    color: pair.colorOf(uid),
    photo: (isPartner ? nickname.photo : null) ?? photos[uid],
  );
}

class ProfileRepository {
  ProfileRepository(this._db);

  final FirebaseFirestore _db;

  /// Everyone's own profile photo, keyed by uid.
  Stream<Map<String, Uint8List>> watchPhotos(String pairId) =>
      _db.collection('pairs/$pairId/profiles').snapshots().map((s) => {
            for (final d in s.docs)
              if (d.data()['photo'] is Blob) d.id: (d.data()['photo'] as Blob).bytes,
          });

  Stream<Nickname> watchNickname(String pairId, String uid) => _db
      .doc('pairs/$pairId/nicknames/$uid')
      .snapshots()
      .map((s) => Nickname.fromMap(s.data()));

  Future<void> setPhoto(String pairId, String uid, Uint8List? bytes) =>
      _db.doc('pairs/$pairId/profiles/$uid').set({
        'photo': bytes == null ? null : Blob(bytes),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setName(String pairId, String uid, String name) =>
      _db.doc('pairs/$pairId').update({'names.$uid': name});

  Future<void> setPetName(String pairId, String uid, String? petName) =>
      _db.doc('pairs/$pairId/nicknames/$uid').set({
        'petName': petName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> setPartnerPhoto(String pairId, String uid, Uint8List? bytes) =>
      _db.doc('pairs/$pairId/nicknames/$uid').set({
        'photo': bytes == null ? null : Blob(bytes),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}

final profileRepositoryProvider =
    Provider((ref) => ProfileRepository(ref.watch(firestoreProvider)));

final profilePhotosProvider = StreamProvider<Map<String, Uint8List>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield const {};
    return;
  }
  yield* ref.watch(profileRepositoryProvider).watchPhotos(pair.id);
});

/// Your private pet name and photo for your partner.
final nicknameProvider = StreamProvider<Nickname>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  final uid = await ref.watch(uidProvider.future);
  if (pair == null) {
    yield Nickname.none;
    return;
  }
  yield* ref.watch(profileRepositoryProvider).watchNickname(pair.id, uid);
});

/// How each member of the pair appears on this phone, keyed by uid.
final peopleProvider = Provider<Map<String, Person>>((ref) {
  final pair = ref.watch(pairProvider).value;
  final viewer = ref.watch(uidProvider).value;
  if (pair == null || viewer == null) return const {};
  final photos = ref.watch(profilePhotosProvider).value ?? const {};
  final nickname = ref.watch(nicknameProvider).value ?? Nickname.none;
  return {
    for (final m in pair.members)
      m: resolvePerson(pair: pair, viewer: viewer, uid: m, photos: photos, nickname: nickname),
  };
});

enum PhotoAction { camera, gallery, remove }

/// Bottom sheet offering camera, gallery and (when [canRemove]) removal.
Future<PhotoAction?> choosePhotoAction(BuildContext context, {required bool canRemove}) =>
    showModalBottomSheet<PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, PhotoAction.gallery),
            ),
            if (canRemove)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, PhotoAction.remove),
              ),
          ],
        ),
      ),
    );

/// Picks a small JPEG (320px) from the camera or gallery, or null if
/// cancelled. Shows a message when the picture is still too large.
Future<Uint8List?> pickPhoto(BuildContext context, PhotoAction action) async {
  final picked = await ImagePicker().pickImage(
    source: action == PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 320,
    maxHeight: 320,
    imageQuality: 75,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  if (bytes.length > profilePhotoMaxBytes) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That photo is too large. Try another one.')),
      );
    }
    return null;
  }
  return bytes;
}
