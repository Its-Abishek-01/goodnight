import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/lovenote/love_note.dart';

LoveNote _note(String id, String from, {DateTime? seenAt, DateTime? sentAt}) =>
    LoveNote(
      id: id,
      from: from,
      text: 'hi',
      sentAt: sentAt ?? DateTime(2026, 1, 1),
      seenAt: seenAt,
    );

void main() {
  group('loveNoteError', () {
    test('rejects an empty or whitespace note', () {
      expect(loveNoteError(''), isNotNull);
      expect(loveNoteError('   '), isNotNull);
    });

    test('rejects a note over the limit', () {
      expect(loveNoteError('a' * (loveNoteMaxLen + 1)), isNotNull);
    });

    test('accepts a trimmed note within the limit', () {
      expect(loveNoteError('  love you  '), isNull);
      expect(loveNoteError('a' * loveNoteMaxLen), isNull);
    });
  });

  test('normalizeNote trims surrounding whitespace', () {
    expect(normalizeNote('  hey  '), 'hey');
  });

  group('latestIncomingUnseen', () {
    const me = 'me';
    const you = 'you';

    test('returns the newest unseen note from the partner', () {
      final all = [
        _note('c', you),
        _note('b', me),
        _note('a', you, seenAt: DateTime(2026, 1, 2)),
      ];
      expect(latestIncomingUnseen(all, me)?.id, 'c');
    });

    test('ignores my own notes and ones already seen', () {
      final all = [
        _note('b', me),
        _note('a', you, seenAt: DateTime(2026, 1, 2)),
      ];
      expect(latestIncomingUnseen(all, me), isNull);
    });
  });

  test('latestSentBy returns my newest note', () {
    const me = 'me';
    final all = [_note('c', 'you'), _note('b', me), _note('a', me)];
    expect(latestSentBy(all, me)?.id, 'b');
  });

  test('expiredOwnNotes only lists my notes past the keep window', () {
    const me = 'me';
    final now = DateTime(2026, 1, 20);
    final all = [
      _note('fresh', me, sentAt: now.subtract(const Duration(days: 1))),
      _note('old', me, sentAt: now.subtract(const Duration(days: loveNoteKeepDays + 1))),
      _note('partnerOld', 'you', sentAt: now.subtract(const Duration(days: loveNoteKeepDays + 1))),
    ];
    final expired = expiredOwnNotes(all, me, now).map((n) => n.id).toList();
    expect(expired, ['old']);
  });
}
