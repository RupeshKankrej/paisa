import 'dart:math';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Motion tokens and the Reduce Motion check (SPEC 5.15).
abstract final class AppMotion {
  static const quick = Duration(milliseconds: 200);
}

extension MotionOf on BuildContext {
  /// iOS Reduce Motion arrives only as `reduceMotion`, while Android's setting
  /// sets `disableAnimations`, so neither is enough alone.
  bool get reduceMotion =>
      (MediaQuery.maybeDisableAnimationsOf(this) ?? false) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;

  /// [duration], or instant under Reduce Motion.
  Duration motion([Duration duration = AppMotion.quick]) =>
      reduceMotion ? Duration.zero : duration;
}

/// iOS page transitions that collapse under Reduce Motion, which the framework
/// only does for Android's setting.
class ReducibleIosTransitions extends PageTransitionsBuilder {
  const ReducibleIosTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => context.reduceMotion
      ? child
      : const CupertinoPageTransitionsBuilder().buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}

/// Fades and slides [child] in once, staggered by [index]. From the 11th item
/// on it shows at once (SPEC 5.15).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const _maxAnimated = 10;
  static const _stagger = Duration(milliseconds: 20);

  // Decided once, so the tree under it keeps its shape for the row's whole life.
  late final bool _animates =
      widget.index < _maxAnimated && !context.reduceMotion;
  AnimationController? _controller;

  // A lazy list would otherwise replay the entrance on scrolling back.
  @override
  bool get wantKeepAlive => widget.index < _maxAnimated;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_animates) return widget.child;
    final delay = _stagger * widget.index;
    final total = delay + AppMotion.quick;
    final controller = _controller ??= AnimationController(
      vsync: this,
      duration: total,
    )..forward();
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOut,
      ),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// What a tab's page needs to know about the sliding tab change (SPEC 5.15).
class TabScope extends InheritedWidget {
  const TabScope({
    super.key,
    required this.active,
    required this.entries,
    required this.shift,
    required super.child,
  });

  /// Whether this is the selected tab, also while it slides in.
  final bool active;

  /// Goes up each time this tab is entered, which replays [Entrance].
  final int entries;

  /// How far the page is off its place now, in points.
  final ValueListenable<double> shift;

  static TabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabScope>();

  @override
  bool updateShouldNotify(TabScope old) =>
      active != old.active || entries != old.entries;
}

/// Keeps [child] still on screen while its page slides, as the FAB and settings
/// button belong to every tab. The leaving page's copy hides at once, as the
/// arriving page's copy is in the same place.
class StayPut extends StatelessWidget {
  const StayPut({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = TabScope.maybeOf(context);
    if (scope == null) return child;
    return Offstage(
      offstage: !scope.active,
      child: ValueListenableBuilder(
        valueListenable: scope.shift,
        builder: (_, shift, child) =>
            Transform.translate(offset: Offset(-shift, 0), child: child),
        child: child,
      ),
    );
  }
}

/// Runs from 0 to 1 when it appears, when its tab is entered and when
/// [replayKey] changes. Stays at 1 under Reduce Motion.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.builder,
    this.replayKey,
    this.duration = const Duration(milliseconds: 450),
    this.child,
  });

  final Widget Function(BuildContext context, double progress, Widget? child)
  builder;
  final Object? replayKey;
  final Duration duration;
  final Widget? child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final _progress = _controller.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  int? _entries;
  var _started = false;

  void _play() {
    if (context.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TabScope.maybeOf(context);
    final entries = scope?.entries;
    if (!_started || (entries != _entries && (scope?.active ?? false))) _play();
    _started = true;
    _entries = entries;
  }

  @override
  void didUpdateWidget(Entrance old) {
    super.didUpdateWidget(old);
    if (widget.replayKey != old.replayKey) _play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) =>
        widget.builder(context, _progress.value, child),
  );
}

/// Reveals [child] clockwise from 12 o'clock as [progress] goes to 1.
class SweepReveal extends StatelessWidget {
  const SweepReveal({super.key, required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _Wedge(progress),
    // Off at 1, so a settled chart pays nothing for this.
    clipBehavior: progress < 1 ? Clip.antiAlias : Clip.none,
    child: child,
  );
}

class _Wedge extends CustomClipper<Path> {
  const _Wedge(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: size.longestSide);
    return Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -pi / 2, 2 * pi * progress.clamp(0.0, 0.9999), false)
      ..close();
  }

  @override
  bool shouldReclip(_Wedge old) => old.progress != progress;
}
