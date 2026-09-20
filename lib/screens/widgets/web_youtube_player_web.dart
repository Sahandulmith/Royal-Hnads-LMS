import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

Widget buildWebYoutubePlayer(String youtubeId, {bool fitOriginal = true}) {
  // Use a unique viewType per video and fit mode to avoid registration conflicts
  final modeKey = fitOriginal ? 'fit' : 'zoom';
  final viewType = 'yt-secure-player-$youtubeId-$modeKey';

  try {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        // ── Container ────────────────────────────────────────────────────────
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'relative'
          ..style.backgroundColor = '#000000'
          ..style.overflow = 'hidden'
          // Prevent text selection
          ..style.userSelect = 'none'
          ..style.setProperty('-webkit-user-select', 'none', '')
          ..style.setProperty('-moz-user-select', 'none', '');

        // ── YouTube iframe (unzoomed 1.0x for full original video or 1.25x crop fill) ──
        final iframeScale = fitOriginal ? 'scale(1.0)' : 'scale(1.25)';
        final shieldHeight = fitOriginal ? '0px' : '48px';

        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube-nocookie.com/embed/$youtubeId'
              '?autoplay=1&controls=0&rel=0&modestbranding=1'
              '&enablejsapi=1&disablekb=1&fs=0&iv_load_policy=3'
              '&playsinline=1&color=white'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.left = '0'
          ..style.transform = iframeScale
          ..style.transformOrigin = 'center center'
          ..allow =
              'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = false;

        // ── Top & Bottom Shield Overlays (Hide residual title/link/YouTube bars) ──
        final topShield = html.DivElement()
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.left = '0'
          ..style.width = '100%'
          ..style.height = shieldHeight
          ..style.zIndex = '90'
          ..style.backgroundColor = '#000000'
          ..style.pointerEvents = 'none';

        final bottomShield = html.DivElement()
          ..style.position = 'absolute'
          ..style.bottom = '0'
          ..style.left = '0'
          ..style.width = '100%'
          ..style.height = shieldHeight
          ..style.zIndex = '90'
          ..style.backgroundColor = '#000000'
          ..style.pointerEvents = 'none';

        // ── Transparent Security Overlay ─────────────────────────────────────
        // Sits on TOP of the iframe — blocks all YouTube native UI clicks & link copies.
        bool isPlaying = true;

        final overlay = html.DivElement()
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.left = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.zIndex = '100'
          ..style.cursor = 'pointer'
          ..style.backgroundColor = 'transparent';

        // Click → toggle play/pause via YouTube IFrame API
        overlay.onClick.listen((_) {
          final cmd = isPlaying
              ? '{"event":"command","func":"pauseVideo","args":""}'
              : '{"event":"command","func":"playVideo","args":""}';
          iframe.contentWindow?.postMessage(cmd, '*');
          isPlaying = !isPlaying;
        });

        // Block right-click & copy shortcuts on entire container
        container.onContextMenu.listen((e) => e.preventDefault());
        overlay.onContextMenu.listen((e) => e.preventDefault());
        container.onCopy.listen((e) => e.preventDefault());

        // Auto-send play command after iframe loads
        iframe.onLoad.listen((_) {
          Future.delayed(const Duration(milliseconds: 800), () {
            iframe.contentWindow?.postMessage(
              '{"event":"command","func":"playVideo","args":""}',
              '*',
            );
          });
        });

        container.append(iframe);
        container.append(topShield);
        container.append(bottomShield);
        container.append(overlay);

        return container;
      },
    );
  } catch (_) {
    // Factory already registered for this viewType — safe to ignore
  }

  return HtmlElementView(viewType: viewType);
}
