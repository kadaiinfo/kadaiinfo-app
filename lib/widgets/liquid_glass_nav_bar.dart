// Liquid Glass のフローティングナビゲーションバー。
//
// ガラスそのものの描画は liquid_glass.dart の LiquidGlassPanel が担う。
// このファイルはバーとしての配置とアイコン・ラベルだけを扱う。
//
// 従来の CurvedNavigationBar に戻したい場合は main.dart の
// kUseLiquidGlassNavBar を false にする。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liquid_glass.dart';

class LiquidGlassNavItem {
  const LiquidGlassNavItem({required this.icon, this.label});

  final IconData icon;

  /// 項目名。アイコンの下に表示し、スクリーンリーダーにも読ませる。
  final String? label;
}

class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    Key? key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 64.0,
    this.horizontalMargin = 22.0,
    this.bottomMargin = 16.0,
    this.glassStyle = LiquidGlassStyle.regular,
    this.tintColor,
    this.selectionColor,
    this.selectionInset = 4.0,
    this.showLabels = true,
    this.selectedColor,
    this.unselectedColor,
  })  : assert(items.length > 0),
        super(key: key);

  final List<LiquidGlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// ガラス板の高さ。マージンは含まない。
  final double height;

  final double horizontalMargin;

  /// 画面下端からの距離。安全領域は加算しないので、変更前の
  /// CurvedNavigationBar と同じ 16 が既定。小さくするほど下に寄る。
  final double bottomMargin;

  /// バー本体のガラスの種類。
  final LiquidGlassStyle glassStyle;

  final Color? tintColor;

  /// 選択中の項目に敷くカプセルの色。
  /// 既定はガラスをうっすら暗く沈ませる半透明の黒（ダークでは白）。
  final Color? selectionColor;

  /// カプセルを項目セルからどれだけ内側に置くか。
  final double selectionInset;

  /// アイコンの下に項目名を表示する。iOS のタブバーは既定でラベルを出す。
  final bool showLabels;

  /// 選択中のアイコンとラベルの色。既定は iOS の label 相当（黒／白）。
  final Color? selectedColor;

  /// 非選択のアイコンとラベルの色。既定は iOS の secondaryLabel 相当。
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
          selection: LiquidGlassSelection(
            itemCount: items.length,
            index: currentIndex,
            // Slack のボトムナビと同じく、選択中だけを少し暗く沈ませる。
            color: selectionColor ??
                (isDark
                    ? Colors.white.withOpacity(0.14)
                    : Colors.black.withOpacity(0.08)),
            inset: selectionInset,
          ),
          child: _NavIconRow(
            items: items,
            currentIndex: currentIndex,
            onTap: onTap,
            showLabels: showLabels,
            // iOS の label 相当。
            selectedColor:
                selectedColor ?? (isDark ? Colors.white : Colors.black),
            // iOS の secondaryLabel 相当。
            unselectedColor: unselectedColor ??
                (isDark
                    ? Colors.white.withOpacity(0.45)
                    : Colors.black.withOpacity(0.45)),
          ),
        ),
      ),
    );
  }
}

class _NavIconRow extends StatelessWidget {
  const _NavIconRow({
    Key? key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.showLabels,
    required this.selectedColor,
    required this.unselectedColor,
  }) : super(key: key);

  final List<LiquidGlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showLabels;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    final int safeIndex = currentIndex.clamp(0, items.length - 1);

    return Row(
      children: List<Widget>.generate(items.length, (int index) {
        final bool selected = index == safeIndex;
        return Expanded(
          child: _NavIcon(
            item: items[index],
            selected: selected,
            showLabel: showLabels,
            color: selected ? selectedColor : unselectedColor,
            onTap: () {
              if (index != currentIndex) {
                HapticFeedback.selectionClick();
              }
              onTap(index);
            },
          ),
        );
      }),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    Key? key,
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  final LiquidGlassNavItem item;
  final bool selected;
  final bool showLabel;
  final Color color;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final bool withLabel = showLabel && item.label != null;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TweenAnimationBuilder<Color?>(
                duration: _duration,
                curve: Curves.easeOut,
                tween: ColorTween(end: color),
                builder: (BuildContext context, Color? animated, Widget? _) {
                  return Icon(
                    item.icon,
                    size: withLabel ? 24.0 : 26.0,
                    color: animated ?? color,
                  );
                },
              ),
              if (withLabel) ...<Widget>[
                const SizedBox(height: 2.0),
                // 長いラベルでも折り返さずに縮める。
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: _duration,
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 10.0,
                      height: 1.1,
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: Text(item.label!, maxLines: 1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
