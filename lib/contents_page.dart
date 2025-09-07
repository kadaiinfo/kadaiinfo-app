import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ContentsPage extends StatefulWidget {
  @override
  _ContentsPageState createState() => _ContentsPageState();
}

class _ContentsPageState extends State<ContentsPage> {
  final String contentsUrl = 'https://kadaiinfo.com/freepaper';
  late final WebViewController _controller; // WebViewコントローラー

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1 Accept-Language: ja-JP,ja;q=0.9,en;q=0.8')
      ..enableZoom(true)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          await _controller.runJavaScript('''
            if (typeof document !== 'undefined') {
              document.querySelector('html').setAttribute('lang', 'ja');
              navigator.language = 'ja-JP';
              navigator.languages = ['ja-JP', 'ja', 'en'];
            }
          ''');
        },
      ))
      ..loadRequest(Uri.parse(contentsUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.0), // アプリバーの高さを設定
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0, // 影を消す
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack(); // WebViewの前のページに戻る
              } else {
                // WebViewで戻るページがない場合は、アプリの前の画面に戻る
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
