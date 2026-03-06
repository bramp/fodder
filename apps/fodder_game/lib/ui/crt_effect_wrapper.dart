import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A wrapper widget that applies a CRT shader effect to its child.
///
/// The shader has:
/// * Scanlines: Horizontal lines that mimic the low-resolution feel of CRT
///   monitors.
/// * Aperture Grille Mask: Subpixel vertical strips (Red, Green, Blue) for that
///   authentic Trinitron look.
/// * Curved Vignette: Subtle darkening of the corners to simulate a rounded
///   glass screen.
/// * Phosphor Noise: Subtle film grain static.
///
/// Uses [FutureBuilder] for clean loading and [AnimatedBuilder] to ensure
/// only the shader is updated every frame, leaving the [child] untouched.
class CrtEffectWrapper extends StatefulWidget {
  const CrtEffectWrapper({required this.child, super.key});

  final Widget child;

  @override
  State<CrtEffectWrapper> createState() => _CrtEffectWrapperState();
}

class _CrtEffectWrapperState extends State<CrtEffectWrapper>
    with SingleTickerProviderStateMixin {
  late Future<ui.FragmentProgram> _programFuture;
  late AnimationController _controller;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();

    // 1. Kick off the async loading immediately.
    _programFuture = ui.FragmentProgram.fromAsset('assets/shaders/crt.frag');

    // 2. Use a controller tasked solely with driving the repaint loop.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    unawaited(_controller.repeat());

    _stopwatch.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.FragmentProgram>(
      future: _programFuture,
      builder: (context, snapshot) {
        // If the shader isn't ready, just show the game normally.
        if (!snapshot.hasData) {
          return widget.child;
        }

        final program = snapshot.data!;

        // AnimatedBuilder listens to the controller and calls the builder
        // on every frame, but it passes the 'widget.child' back through the
        // 'child' parameter so it isn't rebuilt.
        return AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, cachedChild) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return program.fragmentShader()
                  ..setFloat(
                    0,
                    _stopwatch.elapsedMicroseconds / 1000000.0,
                  ) // uTime
                  ..setFloat(1, bounds.width) // uSize.x
                  ..setFloat(2, bounds.height); // uSize.y
              },
              child: cachedChild,
            );
          },
        );
      },
    );
  }
}
