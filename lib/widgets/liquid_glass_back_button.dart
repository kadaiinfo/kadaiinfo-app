// Liquid Glass の丸い戻るボタン。
//
// ナビゲーションバーを出さないページで、ホームへ戻る手段として画面左上に浮かせる。
// ガラスの描画は liquid_glass.dart の LiquidGlassPanel に任せる。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liquid_glass.dart';

class LiquidGlassBackButton extends StatelessWidget {
  const LiquidGlassBackButton({
    Key? key,
    required this.onPressed,
    this.size = 44.0,
    this.icon = Icons.arrow_back_ios_new,
    this.trailingIcon,
    this.iconColor,
    this.semanticLabel = '戻る',
  }) : super(key: key);

  final VoidCallback onPressed;

  /// ボタンの高さ。アイコンが 1 つのときは直径にもなる。
  /// 44 は iOS のタップ領域の下限。
  final double size;

  final IconData icon;

  /// 矢印の右に並べるアイコン。遷移先が WebView の履歴ではないページで、
  /// どこへ戻るのかを示すために使う（グルメページのホームアイコンなど）。
  /// 指定するとボタンは円ではなくカプセル形に伸びる。
  final IconData? trailingIcon;

  final Color? iconColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // iOS の label 相当。
    final Color color = iconColor ?? (isDark ? Colors.white : Colors.black);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: trailingIcon == null ? size : size * 1.6,
        height: size,
        child: LiquidGlassPanel(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: size * 0.40, color: color),
                  if (trailingIcon != null) ...<Widget>[
                    SizedBox(width: size * 0.09),
                    Icon(trailingIcon, size: size * 0.46, color: color),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
