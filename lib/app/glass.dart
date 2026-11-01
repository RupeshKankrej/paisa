import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/motion.dart';
import '../core/theme/tokens.dart';

/// What glass surfaces render with. [lens] is null where refraction cannot run.
class GlassStyle {
  const GlassStyle([this.lens]);

  final FragmentProgram? lens;
}

/// Liquid Glass needs iOS 26 or later (SPEC 5.15).
bool glassSupported(bool isIOS, String osVersion) {
  if (!isIOS) return false;
  final major = RegExp(r'\d+').firstMatch(osVersion)?.group(0);
  return major != null && int.parse(major) >= 26;
}

const _accessibility = MethodChannel('paisa/accessibility');

/// Null means flat: below iOS 26, on Android, or under Reduce Transparency,
/// which Flutter does not expose. Re-read on resume, as the setting lives
/// outside the app. An error also leaves surfaces flat.
final glassProvider = FutureProvider<GlassStyle?>((ref) async {
  if (!glassSupported(Platform.isIOS, Platform.operatingSystemVersion)) {
    return null;
  }
  final reduced = await _accessibility.invokeMethod<bool>('reduceTransparency');
  if (reduced ?? true) return null;
  return GlassStyle(await FragmentProgram.fromAsset('shaders/glass.frag'));
});

/// A blurred, saturated, refracting surface, or a flat colour when
/// [glassProvider] says so. Both paths build the same tree, so [child] keeps its
/// state if the setting changes while it is on screen.
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    super.key,
    required this.borderRadius,
    required this.child,
    this.color,
    this.opacity = 0.3,
    this.refract = true,
    this.flat = false,
    this.moves,
  });

  final BorderRadius borderRadius;
  final Widget child;

  /// Defaults to the palette's surface, the flat fallback SPEC 5.15 names.
  final Color? color;

  /// How much of [color] lies over the glass. Unused when flat.
  final double opacity;

  /// Off for anything that moves without a repaint, such as a scrolling row:
  /// the lens is placed at paint time and would be left behind.
  final bool refract;

  /// Forces the flat look, to keep to two stacked glass layers.
  final bool flat;

  /// Fires when this surface moves, so the lens follows it.
  final Listenable? moves;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = flat ? null : ref.watch(glassProvider).value;
    final base = color ?? context.palette.surface;
    final light = Theme.of(context).brightness == Brightness.light;
    return ClipRRect(
      borderRadius: borderRadius,
      child: _GlassFilter(
        style: style,
        refract: refract,
        radius: borderRadius.topLeft.x,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
        moves: moves,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style == null ? base : base.withValues(alpha: opacity),
          ),
          position: DecorationPosition.background,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              // The inner highlight.
              border: style == null
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: light ? 0.6 : 0.16),
                    ),
            ),
            // Ink from rows inside must draw above the tint.
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

class _GlassFilter extends SingleChildRenderObjectWidget {
  const _GlassFilter({
    required this.style,
    required this.refract,
    required this.radius,
    required this.pixelRatio,
    required this.moves,
    this.clear = 0,
    required super.child,
  });

  final GlassStyle? style;
  final bool refract;
  final double radius;
  final double pixelRatio;
  final Listenable? moves;
  final double clear;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGlass()
    ..style = style
    ..refract = refract
    ..radius = radius
    ..pixelRatio = pixelRatio
    ..moves = moves
    ..clear = clear;

  @override
  void updateRenderObject(BuildContext context, _RenderGlass renderObject) =>
      renderObject
        ..style = style
        ..refract = refract
        ..radius = radius
        ..pixelRatio = pixelRatio
        ..moves = moves
        ..clear = clear;
}

class _RenderGlass extends RenderProxyBox {
  // About 20 px of blur, inside SPEC 5.15's range and light enough for the
  // bending to stay visible.
  static final _frost = ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturate),
    inner: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  );

  // Saturation 1.3, using the Rec. 709 luma weights.
  static const _saturate = <double>[
    1.2362, -0.2146, -0.0216, 0, 0, //
    -0.0638, 1.0854, -0.0216, 0, 0, //
    -0.0638, -0.2146, 1.2784, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  GlassStyle? _style;
  FragmentShader? _shader;
  bool refract = true;
  double radius = 0;
  double pixelRatio = 1;
  Listenable? _moves;
  double _clear = 0;

  /// Above 0 this is the nav's clear lens, at that strength.
  set clear(double value) {
    if (value == _clear) return;
    _clear = value;
    markNeedsPaint();
  }

  set style(GlassStyle? value) {
    if (identical(value, _style)) return;
    _style = value;
    _shader?.dispose();
    _shader = null;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set moves(Listenable? value) {
    if (identical(value, _moves)) return;
    if (attached) {
      _moves?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _moves = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _moves?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _moves?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => _style != null;

  ImageFilter _filter() {
    final lens = _style?.lens;
    if (!refract || lens == null || !ImageFilter.isShaderFilterSupported) {
      return _frost;
    }
    final origin = localToGlobal(Offset.zero) * pixelRatio;
    // Floats 0 and 1 are uSize, which the engine fills in.
    final shader = (_shader ??= lens.fragmentShader())
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, size.width * pixelRatio)
      ..setFloat(5, size.height * pixelRatio)
      ..setFloat(6, radius * pixelRatio)
      ..setFloat(7, 1 + 0.12 * _clear)
      ..setFloat(8, _clear > 0 ? 0.3 : 0.06)
      ..setFloat(9, _clear > 0 ? _clear : 1)
      // A thin rim on the clear lens, so what it covers stays readable.
      ..setFloat(10, _clear > 0 ? 16 * pixelRatio : 90);
    // A clear lens shows the content sharp, so it has no frost.
    return _clear > 0
        ? ImageFilter.shader(shader)
        : ImageFilter.compose(outer: ImageFilter.shader(shader), inner: _frost);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final noLens = _style?.lens == null || !ImageFilter.isShaderFilterSupported;
    if (_style == null || (_clear > 0 && noLens)) {
      super.paint(context, offset);
      return;
    }
    context.pushLayer(
      BackdropFilterLayer(filter: _filter()),
      super.paint,
      offset,
    );
  }
}

/// The clear lens the nav selector lifts into: no frost, magnifies what is under
/// it and bends it at the rim. [strength] runs from 0, no effect, to 1.
class GlassLens extends ConsumerWidget {
  const GlassLens({super.key, required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.circular(AppRadii.round);
    return ClipRRect(
      borderRadius: radius,
      child: _GlassFilter(
        style: ref.watch(glassProvider).value,
        refract: true,
        radius: AppRadii.round,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
        moves: null,
        clear: strength,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white.withValues(alpha: 0.05 * strength),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45 * strength),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// A filter chip on glass. The chip's own fill is cleared so the glass shows.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.chip),
      refract: false, // chips scroll with the list
      child: Theme(
        data: theme.copyWith(
          // The glass must match the chip's visible size.
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          chipTheme: theme.chipTheme.copyWith(
            backgroundColor: Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }
}

var _openSheets = 0;

/// The one way to open a bottom sheet: glass, a drag handle, and instant under
/// Reduce Motion (SPEC 5.15). A sheet over another sheet is flat, as it would be
/// the third stacked glass layer over the nav and the sheet below.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = false,
  Color? color,
}) async {
  final flat = _openSheets > 0;
  _openSheets++;
  try {
    return await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      showDragHandle: false, // drawn on the glass, which sits inside the sheet
      sheetAnimationStyle: context.reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              curve: Curves.easeOutCubic,
              duration: Duration(milliseconds: 320),
              reverseDuration: Duration(milliseconds: 220),
            ),
      builder: (sheet) => GlassSurface(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
        color: color,
        opacity: 0.72,
        flat: flat,
        moves: ModalRoute.of(sheet)?.animation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kMinInteractiveDimension,
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheet.palette.textSecondary,
                    borderRadius: BorderRadius.circular(AppRadii.round),
                  ),
                ),
              ),
            ),
            Flexible(child: builder(sheet)),
          ],
        ),
      ),
    );
  } finally {
    _openSheets--;
  }
}
