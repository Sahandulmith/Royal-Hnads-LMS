import 'package:flutter/material.dart';
import 'web_live_player_stub.dart'
    if (dart.library.html) 'web_live_player_web.dart';

Widget getWebLivePlayer({
  required String url,
  required String platform,
  required String studentName,
}) {
  return buildWebLivePlayer(
    url: url,
    platform: platform,
    studentName: studentName,
  );
}
