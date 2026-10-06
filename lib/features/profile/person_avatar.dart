import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/partner_color.dart';
import 'profile.dart';

/// [PartnerAvatar] for a member of the pair, with their photo, colour and
/// (for your partner) the pet name you gave them.
class PersonAvatar extends ConsumerWidget {
  const PersonAvatar({super.key, required this.uid, this.size = 44, this.badge});

  final String uid;
  final double size;
  final IconData? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(peopleProvider)[uid];
    return PartnerAvatar(
      name: p?.name ?? '',
      color: p?.color ?? PartnerColor.sky,
      photo: p?.photo,
      size: size,
      badge: badge,
    );
  }
}
