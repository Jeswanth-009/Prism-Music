import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/utils/link_validation.dart';

void main() {
  group('isHostOrSubdomain', () {
    test('matches exact hosts case-insensitively', () {
      expect(isHostOrSubdomain('Spotify.Link', 'spotify.link'), isTrue);
      expect(isHostOrSubdomain('open.spotify.com', 'open.spotify.com'), isTrue);
    });

    test('matches subdomains but not superstrings', () {
      expect(isHostOrSubdomain('a.spotify.link', 'spotify.link'), isTrue);
      expect(isHostOrSubdomain('spotify.link.evil.com', 'spotify.link'), isFalse);
      expect(isHostOrSubdomain('evil-spotify.link', 'spotify.link'), isFalse);
      expect(isHostOrSubdomain('notspotify.link', 'spotify.link'), isFalse);
    });
  });

  group('isSpotifyPlaylistHost', () {
    test('accepts only genuine Spotify hosts', () {
      expect(isSpotifyPlaylistHost('open.spotify.com'), isTrue);
      expect(isSpotifyPlaylistHost('spotify.com'), isTrue);
      expect(isSpotifyPlaylistHost('www.spotify.com'), isTrue);
    });

    test('rejects lookalikes', () {
      expect(isSpotifyPlaylistHost('open.spotify.com.evil.io'), isFalse);
      expect(isSpotifyPlaylistHost('evil.com'), isFalse);
      expect(isSpotifyPlaylistHost('spotify.com.evil.io'), isFalse);
    });
  });

  group('isSpotifyShortLinkHost', () {
    test('accepts spotify.link and its subdomains', () {
      expect(isSpotifyShortLinkHost('spotify.link'), isTrue);
      expect(isSpotifyShortLinkHost('s.spotify.link'), isTrue);
    });

    test('rejects substring lookalikes', () {
      expect(isSpotifyShortLinkHost('spotify.link.evil.com'), isFalse);
      expect(isSpotifyShortLinkHost('evilspotify.link'), isFalse);
      expect(isSpotifyShortLinkHost('notspotify.link.example.net'), isFalse);
    });
  });

  group('isTrustedSpotifyRedirectTarget', () {
    test('trusts only https on open.spotify.com', () {
      expect(
        isTrustedSpotifyRedirectTarget(
            Uri.parse('https://open.spotify.com/playlist/abc')),
        isTrue,
      );
      expect(
        isTrustedSpotifyRedirectTarget(
            Uri.parse('http://open.spotify.com/playlist/abc')),
        isFalse,
      );
      expect(
        isTrustedSpotifyRedirectTarget(
            Uri.parse('https://evil.com/playlist/abc')),
        isFalse,
      );
      expect(
        isTrustedSpotifyRedirectTarget(
            Uri.parse('https://open.spotify.com.evil.io/playlist/abc')),
        isFalse,
      );
    });
  });

  group('isYouTubePlaylistHost', () {
    test('accepts known YouTube hosts', () {
      expect(isYouTubePlaylistHost('youtube.com'), isTrue);
      expect(isYouTubePlaylistHost('music.youtube.com'), isTrue);
      expect(isYouTubePlaylistHost('youtu.be'), isTrue);
    });

    test('rejects lookalikes', () {
      expect(isYouTubePlaylistHost('youtube.com.evil.io'), isFalse);
      expect(isYouTubePlaylistHost('evilyoutube.com'), isFalse);
    });
  });
}
