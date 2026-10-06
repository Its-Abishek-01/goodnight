import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../pairing/pair.dart';
import '../pairing/pair_providers.dart';
import '../pairing/partner_color.dart';
import 'person_avatar.dart';
import 'profile.dart';

/// Top of the Us tab: your profile (seen by both of you) and how your
/// partner appears on your phone (seen only by you).
class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  Future<void> _photo(
    BuildContext context, {
    required bool hasPhoto,
    required Future<void> Function(Uint8List? bytes) save,
  }) async {
    final action = await choosePhotoAction(context, canRemove: hasPhoto);
    if (action == null || !context.mounted) return;
    if (action == PhotoAction.remove) return save(null);
    final bytes = await pickPhoto(context, action);
    if (bytes != null) await save(bytes);
  }

  Future<String?> _ask(BuildContext context, String title, String initial, String hint) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(profileRepositoryProvider);
    final photos = ref.watch(profilePhotosProvider).value ?? const {};
    final nickname = ref.watch(nicknameProvider).value ?? Nickname.none;
    final partnerUid = pair.partnerUid(uid) ?? '';
    final partnerRealName = pair.nameOf(partnerUid);
    final partnerShown = ref.watch(peopleProvider)[partnerUid]?.name ?? partnerRealName;
    final text = Theme.of(context).textTheme;

    Widget editableAvatar(String who, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PersonAvatar(uid: who, size: 76),
              const Positioned(
                right: -2,
                bottom: -2,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: GnColors.moon,
                  child: Icon(Icons.photo_camera, size: 15, color: GnColors.onMoon),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    editableAvatar(
                      uid,
                      () => _photo(
                        context,
                        hasPhoto: photos[uid] != null,
                        save: (b) => repo.setPhoto(pair.id, uid, b),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You', style: text.labelMedium?.copyWith(color: GnColors.muted)),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final name = (await _ask(context, 'Your name', pair.nameOf(uid), 'Your name'))?.trim();
                              if (name != null && name.isNotEmpty) await repo.setName(pair.id, uid, name);
                            },
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    pair.nameOf(uid),
                                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit, size: 16, color: GnColors.muted),
                              ],
                            ),
                          ),
                          Text('Tap the photo to change it', style: text.bodySmall?.copyWith(color: GnColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Your colour', style: text.titleSmall),
                const SizedBox(height: 10),
                PartnerColorPicker(
                  selected: pair.colorOf(uid),
                  taken: pair.colorOf(partnerUid),
                  onChanged: (c) => ref.read(pairRepositoryProvider).setColor(pair.id, uid, c),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    editableAvatar(
                      partnerUid,
                      () => _photo(
                        context,
                        hasPhoto: nickname.photo != null,
                        save: (b) => repo.setPartnerPhoto(pair.id, uid, b),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your partner', style: text.labelMedium?.copyWith(color: GnColors.muted)),
                          Text(
                            partnerShown,
                            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (nickname.petName != null)
                            Text('Real name: $partnerRealName', style: text.bodySmall?.copyWith(color: GnColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final pet = await _ask(
                      context,
                      'Pet name for $partnerRealName',
                      nickname.petName ?? '',
                      'Baby, Jaan, Sunshine…',
                    );
                    if (pet != null) await repo.setPetName(pair.id, uid, pet.trim().isEmpty ? null : pet.trim());
                  },
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: Text(nickname.petName == null ? 'Give a pet name' : 'Change pet name'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only you see the pet name and photo you choose for $partnerRealName.',
                  style: text.bodySmall?.copyWith(color: GnColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
