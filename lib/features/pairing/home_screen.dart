import 'package:flutter/material.dart';

import 'pair.dart';

/// Placeholder home. Bedtime approval, streak and coupons land here later.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final partner = pair.nameOf(pair.partnerUid(uid) ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('GoodNight 🌙')),
      body: Center(
        child: Text(
          'You & $partner are paired ❤️',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
