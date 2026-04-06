import 'package:prism_music/core/services/ytmusic_api_service.dart';

Future<void> main() async {
  final service = YtMusicApiService();
  final queries = ['aaya sher', 'arijit singh', 'new India songs 2026 official'];

  for (final q in queries) {
    final songs = await service.searchSongs(q);
    print('query="$q" songs=${songs.length}');
    if (songs.isNotEmpty) {
      print('first=${songs.first}');
    }
  }
}
