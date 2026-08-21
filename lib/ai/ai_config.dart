/// Where the proxy is and how this device identifies itself.
///
/// Both are supplied at build time and neither is ever committed:
///
///     flutter run --dart-define=BOOKERIZE_PROXY_URL=https://... \
///                 --dart-define=BOOKERIZE_TOKEN=...
///
/// The token is not the API key. It is a name on a list the Worker holds, so
/// losing one costs you a line in a secret rather than your Gemini account.
abstract final class AiConfig {
  static const baseUrl = String.fromEnvironment('BOOKERIZE_PROXY_URL');
  static const token = String.fromEnvironment('BOOKERIZE_TOKEN');

  /// False on any build that was not given both. The app stays fully usable —
  /// the offline dictionary is the part that matters most, and it needs neither.
  static bool get isConfigured => baseUrl.isNotEmpty && token.isNotEmpty;
}
