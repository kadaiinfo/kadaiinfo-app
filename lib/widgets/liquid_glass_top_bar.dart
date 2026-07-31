// 全ページ共通の上部バー。左端にガラスの戻るボタンを置く。
//
// WebView に重ねるとページの内容が隠れてしまうため、浮かせるのではなく
// 専用の帯として高さを確保している。
import 'package:flutter/material.dart';

import 'liquid_glass_back_button.dart';

/// 上部バーの高さ。ステータスバーの領域は含まない。
const double kLiquidGlassTopBarHeight = 56.0;

/// Scaffold の appBar に渡す上部バーを作る。
///
/// preferredSize はステータスバーの高さを含める必要があるため、
/// PreferredSizeWidget のサブクラスではなく context を取る関数にしている。
PreferredSizeWidget liquidGlassTopBar(
  BuildContext context, {
  required VoidCallback onBack,
  IconData? trailingIcon,
  String semanticLabel = '戻る',
  double height = kLiquidGlassTopBarHeight,
}) {
  final double topInset = MediaQuery.of(context).padding.top;

  return PreferredSize(
    preferredSize: Size.fromHeight(topInset + height),
    child: Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: topInset, left: 16.0),
      alignment: Alignment.centerLeft,
      child: LiquidGlassBackButton(
        onPressed: onBack,
        trailingIcon: trailingIcon,
        semanticLabel: semanticLabel,
      ),
    ),
  );
}
