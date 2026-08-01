import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'post_navigator.dart';
import 'widgets/liquid_glass_top_bar.dart';

class ClubPage extends StatefulWidget {
  const ClubPage({Key? key, this.postNavigator, this.onHome}) : super(key: key);

  /// 記事ページで前後の記事へ移動するための状態。
  /// 渡さなければ従来どおり普通の WebView として動く。
  final PostNavigator? postNavigator;

  /// 記事ページで左上のボタンを押したときの遷移先。ホームに戻す想定。
  final VoidCallback? onHome;

  @override
  _ClubPageState createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  final String clubUrl = 'https://kadaiinfo.com/club';
  late final WebViewController _controller; // WebViewコントローラー

  /// 上部バーに読み込み中の表示を出しているか。
  bool _isLoading = false;

  /// いま記事ページを開いているか。左上のボタンの出し分けに使う。
  bool _isPostPage = false;

  /// 読み込みの終わりを拾えなかったときに表示を下ろすためのタイマー。
  Timer? _loadingTimeout;

  /// ページ内遷移は終わりが分からないので、この時間で打ち切る。
  static const Duration _loadingTimeoutDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    final PostNavigator? postNavigator = widget.postNavigator;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1 Accept-Language: ja-JP,ja;q=0.9,en;q=0.8')
      ..enableZoom(true)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _startLoading(),
        // サイトは Next.js なのでページ内遷移では onPageStarted も
        // onPageFinished も呼ばれない。表示中の URL はこちらで追い、
        // 読み込み中の表示もここから始める。
        onUrlChange: (UrlChange change) {
          _startLoading();
          final String? url = change.url;
          if (url != null) {
            _updatePostPage(url);
            postNavigator?.handleUrl(url);
          }
        },
        onPageFinished: (url) async {
          _stopLoading();
          _updatePostPage(url);
          postNavigator?.handleUrl(url);
          await _controller.runJavaScript('''
            if (typeof document !== 'undefined') {
              document.querySelector('html').setAttribute('lang', 'ja');
              navigator.language = 'ja-JP';
              navigator.languages = ['ja-JP', 'ja', 'en'];
            }
          ''');
        },
        onWebResourceError: (_) => _stopLoading(),
      ));

    // 記事の並び順は WebView の中から取りに行くので、受け口を先に用意しておく。
    if (postNavigator != null) {
      _controller.addJavaScriptChannel(
        PostNavigator.channelName,
        onMessageReceived: (JavaScriptMessage message) =>
            postNavigator.handleChannelMessage(message.message),
      );
      postNavigator.attach(_controller);
    }

    _controller.loadRequest(Uri.parse(clubUrl));

    // iOSで画面端スワイプによる「戻る／進む」を有効化（Safari同様の挙動）
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    widget.postNavigator?.detach(_controller);
    super.dispose();
  }

  void _startLoading() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(_loadingTimeoutDuration, _stopLoading);
    if (!_isLoading && mounted) {
      setState(() => _isLoading = true);
    }
  }

  void _stopLoading() {
    _loadingTimeout?.cancel();
    if (_isLoading && mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updatePostPage(String url) {
    final bool isPost = PostNavigator.isPostUrl(url);
    if (isPost != _isPostPage && mounted) {
      setState(() => _isPostPage = isPost);
    }
  }

  /// 記事ページではボトムがタブではなく前後ボタンになるので、
  /// 左上をホームへの出口にする（グルメページと同じ形）。
  bool get _showHomeButton => _isPostPage && widget.onHome != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: liquidGlassTopBar(
        context,
        onBack: _showHomeButton ? widget.onHome! : _goBack,
        trailingIcon: _showHomeButton ? Icons.home : null,
        semanticLabel: _showHomeButton ? 'ホームに戻る' : '戻る',
        isLoading: _isLoading,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack(); // WebViewの前のページに戻る
    } else if (mounted && Navigator.canPop(context)) {
      // WebViewで戻るページがない場合は、アプリの前の画面に戻る
      Navigator.pop(context);
    }
  }
}
