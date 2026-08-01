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
  bool isLoading = false,
}) {
  final double topInset = MediaQuery.of(context).padding.top;

  return PreferredSize(
    preferredSize: Size.fromHeight(topInset + height),
    child: Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: topInset),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LiquidGlassBackButton(
                onPressed: onBack,
                trailingIcon: trailingIcon,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
          // 読み込み中の表示。バーの下端に敷いて、WebView との境目に見せる。
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: _TopBarProgress(isLoading: isLoading),
          ),
        ],
      ),
    ),
  );
}

/// 上部バー下端の読み込みインジケータ。
///
/// 進み具合ではなく、バーが左から右へ流れ続ける形にしている。
/// ページ内遷移では読み込みの割合が取れないので、どの遷移でも同じ見た目で
/// 「待っている」ことだけを伝える。
class _TopBarProgress extends StatelessWidget {
  const _TopBarProgress({Key? key, required this.isLoading}) : super(key: key);

  final bool isLoading;

  static const double _height = 2.5;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        // 出るときも消えるときも薄れるだけにする。位置は動かさない。
        transitionBuilder: (Widget child, Animation<double> animation) =>
            FadeTransition(opacity: animation, child: child),
        child: isLoading
            ? LinearProgressIndicator(
                // value を渡さないと、バーが左から右へ流れ続ける。
                key: const ValueKey<bool>(true),
                minHeight: _height,
                backgroundColor: Colors.transparent,
                // 読み込み中だと分かればよいので、控えめな濃さにする。
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark
                      ? Colors.white.withOpacity(0.35)
                      : Colors.black.withOpacity(0.35),
                ),
              )
            : const SizedBox(
                key: ValueKey<bool>(false),
                height: _height,
                width: double.infinity,
              ),
      ),
    );
  }
}
