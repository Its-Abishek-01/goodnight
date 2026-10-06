import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import 'features.dart';
import 'features_repository.dart';

final featuresRepositoryProvider = Provider(
  (ref) => FeaturesRepository(ref.watch(firestoreProvider)),
);

/// Both people's own feature choices, keyed by uid.
final personalFeaturesProvider = StreamProvider<Map<String, PersonalFeatures>>((
  ref,
) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield {};
    return;
  }
  yield* ref.watch(featuresRepositoryProvider).watchPersonal(pair.id);
});

/// This person's features, or null while they are still loading. The sync
/// providers wait for a value so they never act on the defaults by mistake.
final myFeaturesProvider = Provider<PersonalFeatures?>((ref) {
  final uid = ref.watch(uidProvider).value;
  final all = ref.watch(personalFeaturesProvider).value;
  if (uid == null || all == null) return null;
  return all[uid] ?? PersonalFeatures.all;
});

final sharedSettingsProvider = StreamProvider<SharedSettings>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield SharedSettings.initial;
    return;
  }
  yield* ref.watch(featuresRepositoryProvider).watchShared(pair.id);
});

/// The approved shared features. Everything is on until the couple changes it.
final sharedFeaturesProvider = Provider<SharedFeatures>(
  (ref) =>
      ref.watch(sharedSettingsProvider).value?.current ?? SharedFeatures.all,
);
