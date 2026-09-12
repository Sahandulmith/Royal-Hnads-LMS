import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

Widget buildWebYoutubePlayer(String youtubeId) {
  final viewType = 'youtube-iframe-$youtubeId';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => html.IFrameElement()
      ..src = 'https://www.youtube-nocookie.com/embed/$youtubeId?autoplay=1&enablejsapi=1&rel=0&modestbranding=1'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
      ..allowFullscreen = true,
  );

  return HtmlElementView(viewType: viewType);
}
