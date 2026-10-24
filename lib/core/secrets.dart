// Secrets configuration for third-party integrations
class AppSecrets {
  // Football-data.org API key.
  // Obtain a free tier token from https://www.football-data.org/client/register
  static String footballDataApiKey = "";

  static bool get hasFootballKey => footballDataApiKey.trim().isNotEmpty;
}
