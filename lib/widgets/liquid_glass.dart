// Liquid Glass のガラス面。ナビゲーションバーと戻るボタンで共有する。
//
// iOS では Apple 純正のマテリアル（UIGlassEffect）をプラットフォームビュー経由で
// そのまま描画する。ぼかし量・彩度・縁の光沢・影・屈折といった数値は Apple が
// 公開しておらず OS が描くため、アプリ側では指定しない。指定できるのは Apple が
// 公開している以下のパラメータだけで、それぞれ ios/Runner/LiquidGlass.swift を
// 通して UIKit へ渡される。
//
//   style       -> UIGlassEffect(style:)  .regular / .clear
//   tintColor   -> UIGlassEffect.tintColor
//   interactive -> UIGlassEffect.interactive
//   （角丸）     -> UIView.cornerConfiguration = .capsule()
//
// Android には相当するシステムマテリアルが無いため、BackdropFilter による
// 近似実装にフォールバックする（blurSigma / saturation はそちらでのみ使う）。
//
// 選択中を示すカプセルはガラスではなく単色で塗る。ガラスを 2 枚重ねると
// 色味を細かく制御できず、iOS と Android で見た目も揃わないため。
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;

/// UIGlassEffect.Style に対応する。
enum LiquidGlassStyle {
  /// 標準のガラス。UIGlassEffectStyleRegular。
  regular,

  /// より透明度の高いガラス。UIGlassEffectStyleClear。
  clear,
}

/// ガラス板の中で「選択中の位置」を示すカプセル。
/// ナビゲーションバーでのみ使い、単体のボタンでは指定しない。
class LiquidGlassSelection {
  const LiquidGlassSelection({
    required this.itemCount,
    required this.index,
    required this.color,
    this.inset = 4.0,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  });

  final int itemCount;
  final int index;

  /// カプセルの色。半透明にしてガラスをうっすら暗く沈ませる。
  final Color color;

  /// 項目セルからどれだけ内側に置くか。
  final double inset;

  final Duration duration;
  final Curve curve;
}

/// Liquid Glass のガラス板。[child] はガラスの上に重ねて描かれる。
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    Key? key,
    this.child,
    this.style = LiquidGlassStyle.regular,
    this.tintColor,
    this.interactive = false,
    this.selection,
    this.fallbackBlurSigma = 24.0,
    this.fallbackSaturation = 1.8,
  }) : super(key: key);

  final Widget? child;

  /// UIGlassEffect(style:)。
  final LiquidGlassStyle style;

  /// UIGlassEffect.tintColor。null で無着色。
  final Color? tintColor;

  /// UIGlassEffect.interactive。タッチに追従して歪む挙動。
  /// タップは Flutter 側で処理しておりネイティブビューは触れないため、既定は false。
  final bool interactive;

  /// 選択中の位置を示すカプセル。null なら描かない。
  final LiquidGlassSelection? selection;

  /// 背面のぼかし強度（Android のみ）。
  final double fallbackBlurSigma;

  /// 背面の彩度（Android のみ）。
  final double fallbackSaturation;

  static const String _viewType = 'kadaiinfo/liquid_glass';

  static bool get _useNativeGlass => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final Widget glass = _useNativeGlass
        ? UiKitView(
            viewType: _viewType,
            creationParams: <String, dynamic>{
              'glassStyle': style.name,
              'tintColor': tintColor?.value,
              'interactive': interactive,
            },
            creationParamsCodec: const StandardMessageCodec(),
          )
        : _FallbackGlass(
            style: style,
            tintColor: tintColor,
            blurSigma: fallbackBlurSigma,
            saturation: fallbackSaturation,
          );

    final LiquidGlassSelection? selection = this.selection;
    if (selection == null && child == null) {
      return glass;
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(child: glass),
        if (selection != null)
          Positioned.fill(child: _SelectionCapsule(selection: selection)),
        if (child != null) child!,
      ],
    );
  }
}

/// 選択中の項目に敷くカプセル。
class _SelectionCapsule extends StatelessWidget {
  const _SelectionCapsule({Key? key, required this.selection})
      : super(key: key);

  final LiquidGlassSelection selection;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double itemWidth = constraints.maxWidth / selection.itemCount;
          final int index = selection.index.clamp(0, selection.itemCount - 1);
          final double height = constraints.maxHeight - selection.inset * 2.0;

          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: selection.duration,
                curve: selection.curve,
                left: itemWidth * index + selection.inset,
                top: selection.inset,
                width: itemWidth - selection.inset * 2.0,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height / 2.0),
                    color: selection.color,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Android: BackdropFilter による近似
// ---------------------------------------------------------------------------

class _FallbackGlass extends StatelessWidget {
  const _FallbackGlass({
    Key? key,
    required this.style,
    required this.tintColor,
    required this.blurSigma,
    required this.saturation,
  }) : super(key: key);

  final LiquidGlassStyle style;
  final Color? tintColor;
  final double blurSigma;
  final double saturation;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isClear = style == LiquidGlassStyle.clear;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double radius = constraints.maxHeight / 2.0;

        return DecoratedBox(
          // 影は ClipRRect の外側に置かないと切り取られてしまう。
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.16),
                blurRadius: 24.0,
                offset: const Offset(0.0, 8.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.compose(
                // outer が後に適用される。ぼかしてから彩度を上げる。
                outer: ColorFilter.matrix(_saturationMatrix(saturation)),
                inner: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                  tileMode: TileMode.mirror,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: tintColor ??
                      Colors.white.withOpacity(
                        isDark
                            ? (isClear ? 0.06 : 0.12)
                            : (isClear ? 0.18 : 0.32),
                      ),
                  border: Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.24 : 0.55),
                    width: 1.0,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }

  static List<double> _saturationMatrix(double s) {
    const double lumR = 0.2126;
    const double lumG = 0.7152;
    const double lumB = 0.0722;
    final double r = (1.0 - s) * lumR;
    final double g = (1.0 - s) * lumG;
    final double b = (1.0 - s) * lumB;
    return <double>[
      r + s, g, b, 0.0, 0.0, //
      r, g + s, b, 0.0, 0.0, //
      r, g, b + s, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ];
  }
}
