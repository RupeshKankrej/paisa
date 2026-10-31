import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
