import 'package:flutter/material.dart';
import 'web_youtube_player_stub.dart'
    if (dart.library.html) 'web_youtube_player_web.dart';

Widget getWebYoutubePlayer(String youtubeId, {bool fitOriginal = true}) {
  return buildWebYoutubePlayer(youtubeId, fitOriginal: fitOriginal);
}
