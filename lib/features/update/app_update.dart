/// A GitHub release the app can update itself to.
class AppRelease {
  const AppRelease({
    required this.tag,
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.required,
  });

  /// The tag as published, e.g. `v0.2.2`.
  final String tag;

  /// [tag] without the leading `v`, e.g. `0.2.2`.
  final String version;

  /// The release notes (markdown).
  final String notes;
  final String apkUrl;

  /// Size in bytes as GitHub reports it, used to check the download.
  final int apkSize;

  /// Older versions must update before they can be used. Set by putting
  /// [requiredMarker] anywhere in the release notes.
  final bool required;

  /// Reads the `releases/latest` API response. Null when it has no APK.
  static AppRelease? fromGitHub(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String?;
    if (tag == null || parseVersion(tag) == null) return null;
    final assets = (json['assets'] as List?) ?? const [];
    for (final a in assets.whereType<Map>()) {
      final name = a['name'] as String? ?? '';
      final url = a['browser_download_url'] as String?;
      if (!name.toLowerCase().endsWith('.apk') || url == null) continue;
      final notes = json['body'] as String? ?? '';
      return AppRelease(
        tag: tag,
        version: tag.startsWith('v') ? tag.substring(1) : tag,
        notes: notes,
        apkUrl: url,
        apkSize: (a['size'] as num?)?.toInt() ?? 0,
        required: notes.contains(requiredMarker),
      );
    }
    return null;
  }
}

/// Hidden in the rendered release notes on GitHub; makes an update required.
const requiredMarker = '<!-- required -->';

/// `v0.2.2`, `0.2.2`, `0.2.2+4` and `0.2` all parse; anything else is null.
List<int>? parseVersion(String s) {
  var v = s.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  v = v.split(RegExp(r'[+\-\s]')).first;
  final parts = v.split('.');
  if (parts.isEmpty || parts.length > 3) return null;
  final nums = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    nums.add(n);
  }
  while (nums.length < 3) {
    nums.add(0);
  }
  return nums;
}

/// True when [candidate] is a later version than [installed]. Unparseable
/// versions never count as newer.
bool isNewer(String candidate, String installed) {
  final a = parseVersion(candidate);
  final b = parseVersion(installed);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Whether to show [release] now. "Later" hides that release until
/// [snoozedUntil]; a newer release or a required one shows straight away.
bool shouldOffer({
  required AppRelease release,
  required String installed,
  required DateTime now,
  String? snoozedTag,
  DateTime? snoozedUntil,
}) {
  if (!isNewer(release.version, installed)) return false;
  if (release.required) return true;
  if (snoozedTag == release.tag && snoozedUntil != null && now.isBefore(snoozedUntil)) {
    return false;
  }
  return true;
}

/// Short lines for the popup, from the bullet points of the release notes:
/// each bullet up to its first ": " or ". ", without markdown.
List<String> releaseHighlights(String notes, {int max = 3, int maxLen = 48}) {
  final out = <String>[];
  for (final raw in notes.split('\n')) {
    final line = raw.trim();
    if (!(line.startsWith('- ') || line.startsWith('* '))) continue;
    var t = line.substring(2).replaceAll(RegExp(r'[*_`]'), '');
    t = t.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!);
    final cut = RegExp(r'(: |\. )').firstMatch(t);
    if (cut != null) t = t.substring(0, cut.start);
    t = t.trim();
    if (t.endsWith('.')) t = t.substring(0, t.length - 1);
    if (t.isEmpty) continue;
    if (t.length > maxLen) t = '${t.substring(0, maxLen - 1).trimRight()}…';
    out.add(t);
    if (out.length == max) break;
  }
  return out;
}

/// "14 MB" style size for the popup.
String formatSize(int bytes) {
  if (bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  return mb >= 10 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
}
