/// Exact-host (or subdomain) matching for untrusted user-supplied links.
///
/// Host checks must never be substring-based: `spotify.link.evil.com`,
/// `evil-spotify.link` and `notspotify.link.example` all *contain* a
/// Spotify-looking fragment but are attacker-controlled domains.
library;

/// True when [host] equals [baseHost] exactly or is one of its subdomains.
bool isHostOrSubdomain(String host, String baseHost) {
  final h = host.toLowerCase();
  final b = baseHost.toLowerCase();
  return h == b || h.endsWith('.$b');
}

/// Hosts that legitimately carry Spotify playlist links the app resolves.
bool isSpotifyPlaylistHost(String host) {
  final h = host.toLowerCase();
  return h == 'open.spotify.com' || h == 'spotify.com' || h == 'www.spotify.com';
}

/// spotify.link short links (and their subdomains) redirect to Spotify.
bool isSpotifyShortLinkHost(String host) =>
    isHostOrSubdomain(host, 'spotify.link');

/// A followed spotify.link redirect is only trusted when it lands on the
/// Spotify embed host over HTTPS — never on another domain the redirect
/// chain may have been pointed at.
bool isTrustedSpotifyRedirectTarget(Uri uri) {
  if (!uri.isScheme('https')) return false;
  if (uri.hasPort && uri.port != 443) return false;
  return uri.host.toLowerCase() == 'open.spotify.com';
}

/// Hosts that legitimately carry YouTube playlist links the app imports.
bool isYouTubePlaylistHost(String host) {
  const allowed = {
    'youtube.com',
    'www.youtube.com',
    'music.youtube.com',
    'm.youtube.com',
    'youtu.be',
  };
  return allowed.contains(host.toLowerCase());
}
