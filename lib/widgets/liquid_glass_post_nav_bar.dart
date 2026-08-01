// 記事ページを開いている間だけボトムに出す、左右 2 つのボタンのバー。
//
// 通常のタブバー（liquid_glass_nav_bar.dart）と入れ替えて使うため、
// 高さとマージンはそちらに合わせてある。ガラスの描画は
// liquid_glass.dart の LiquidGlassPanel が担う。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liquid_glass.dart';

class LiquidGlassPostNavBar extends StatelessWidget {
  const LiquidGlassPostNavBar({
    Key? key,
    required this.onNewer,
    required this.onOlder,
    this.hasNewer = false,
    this.hasOlder = false,
    this.isLoading = false,
    this.height = 64.0,
    this.horizontalMargin = 22.0,
    this.bottomMargin = 16.0,
    this.glassStyle = LiquidGlassStyle.regular,
    this.tintColor,
  }) : super(key: key);

  /// 1 つ新しい記事へ。
  final VoidCallback onNewer;

  /// 1 つ古い記事へ。
  final VoidCallback onOlder;

  final bool hasNewer;
  final bool hasOlder;

  /// 前後を探している最中。ボタンは押せないが、行き止まりとは見せない。
  final bool isLoading;

  final double height;
  final double horizontalMargin;
  final double bottomMargin;
  final LiquidGlassStyle glassStyle;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // liquid_glass_nav_bar.dart と同じ iOS の label 相当。
    final Color enabled = isDark ? Colors.white : Colors.black;
    final Color disabled = isDark
        ? Colors.white.withOpacity(0.25)
        : Colors.black.withOpacity(0.25);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        0.0,
        horizontalMargin,
        bottomMargin,
      ),
      child: SizedBox(
        height: height,
        child: LiquidGlassPanel(
          style: glassStyle,
          tintColor: tintColor,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _PostNavButton(
                  icon: Icons.keyboard_double_arrow_left,
                  semanticLabel: '新しい記事',
                  color: hasNewer ? enabled : disabled,
                  onTap: hasNewer ? onNewer : null,
                  showProgress: isLoading,
                ),
              ),
              // 2 つのボタンの境目。押し分けの目印になる程度の細さにする。
              Container(
                width: 1.0,
                height: height * 0.4,
                color: isDark
                    ? Colors.white.withOpacity(0.18)
                    : Colors.black.withOpacity(0.12),
              ),
              Expanded(
                child: _PostNavButton(
                  icon: Icons.keyboard_double_arrow_right,
                  semanticLabel: '古い記事',
                  color: hasOlder ? enabled : disabled,
                  onTap: hasOlder ? onOlder : null,
                  showProgress: isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostNavButton extends StatelessWidget {
  const _PostNavButton({
    Key? key,
    required this.icon,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
    required this.showProgress,
  }) : super(key: key);

  final IconData icon;

  /// 画面には出さないが、スクリーンリーダーには行き先を読ませる。
  final String semanticLabel;

  final Color color;

  /// null のときは行き先が無いので押せない。
  final VoidCallback? onTap;

  final bool showProgress;

  static const Duration _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final bool loading = showProgress && onTap == null;

    final Widget content = loading
        ? SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(strokeWidth: 2.0, color: color),
          )
        : Icon(icon, size: 30.0, color: color);

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: Center(
          child: AnimatedSwitcher(
            duration: _duration,
            child: KeyedSubtree(
              key: ValueKey<bool>(loading),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
