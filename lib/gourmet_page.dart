import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'widgets/liquid_glass_top_bar.dart';

class GourmetPage extends StatefulWidget {
  const GourmetPage({Key? key, required this.onBack}) : super(key: key);

  /// 左上のガラスの戻るボタンを押したときの遷移先。ホームに戻す想定。
  /// このページではボトムナビゲーションを出さないため、これが唯一の脱出口になる。
  /// WebView 内の「前のページへ戻る」は画面端のスワイプで行える
  /// （allowsBackForwardNavigationGestures を有効にしている）。
  final VoidCallback onBack;

  @override
  _GourmetPageState createState() => _GourmetPageState();
}

class _GourmetPageState extends State<GourmetPage> {
  final String gourmetUrl = 'https://gourmet.kadaiinfo.com/';
  late final InAppWebViewController _controller;
  final _storage = FlutterSecureStorage();

  // 保存されているクレデンシャルを取得
  Future<Map<String, String>> _getCredentials() async {
    String? username = await _storage.read(key: 'username');
    String? password = await _storage.read(key: 'password');
    return {
      'username': username ?? '',
      'password': password ?? '',
    };
  }

  // 画像保存機能
  Future<void> _saveImage(dynamic imageUrl) async {
    try {
      if (imageUrl == null) {
        _showSnackBar('画像URLが取得できませんでした');
        return;
      }

      String url = imageUrl.toString();

      // 権限チェック
      var status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
        if (!status.isGranted) {
          _showSnackBar('写真ライブラリへのアクセス許可が必要です');
          return;
        }
      }

      // 画像をダウンロード
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final result = await ImageGallerySaver.saveImage(
          Uint8List.fromList(response.bodyBytes),
          name: "saved_image_${DateTime.now().millisecondsSinceEpoch}",
        );

        if (result['isSuccess']) {
          _showSnackBar('画像を保存しました');
        } else {
          _showSnackBar('画像の保存に失敗しました');
        }
      } else {
        _showSnackBar('画像のダウンロードに失敗しました');
      }
    } catch (e) {
      _showSnackBar('エラーが発生しました: ${e.toString()}');
    }
  }

  // スナックバー表示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // このページはボトムナビゲーションを出さないので、この戻るボタンが
      // ホームへの唯一の導線になる。他ページの戻る（WebView の履歴を 1 つ戻る）と
      // 動作が違うため、ホームのアイコンを並べて遷移先を示す。
      appBar: liquidGlassTopBar(
        context,
        onBack: widget.onBack,
        trailingIcon: Icons.home,
        semanticLabel: 'ホームに戻る',
      ),
      body: _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return FutureBuilder<Map<String, String>>(
        future: _getCredentials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else {
            final credentials = snapshot.data!;
            return InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(gourmetUrl)), // 修正
              initialSettings: InAppWebViewSettings(
                userAgent:
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1 Accept-Language: ja-JP,ja;q=0.9,en;q=0.8',
                supportZoom: true,
                javaScriptEnabled: true,
                preferredContentMode: UserPreferredContentMode.MOBILE,
                // iOSで画面端スワイプによる「戻る／進む」を有効化（Safari同様の挙動）
                allowsBackForwardNavigationGestures: true,
              ),
              contextMenu: ContextMenu(
                settings: ContextMenuSettings(
                  hideDefaultSystemContextMenuItems: false,
                ),
                menuItems: [
                  ContextMenuItem(
                    androidId: 1,
                    iosId: "save_image",
                    title: "画像を保存",
                    action: () async {
                      try {
                        // 現在長押ししている要素の画像URLを取得
                        var result =
                            await _controller.evaluateJavascript(source: '''
                          (function() {
                            var imgs = document.querySelectorAll('img');
                            for (var i = 0; i < imgs.length; i++) {
                              var rect = imgs[i].getBoundingClientRect();
                              if (rect.width > 0 && rect.height > 0) {
                                return imgs[i].src;
                              }
                            }
                            return null;
                          })();
                        ''');

                        if (result != null) {
                          await _saveImage(result);
                        } else {
                          _showSnackBar('画像が見つかりませんでした');
                        }
                      } catch (e) {
                        _showSnackBar('画像の取得に失敗しました');
                      }
                    },
                  ),
                ],
              ),
              onWebViewCreated: (InAppWebViewController controller) {
                _controller = controller;
              },
              onLoadStop: (controller, url) async {
                await controller.evaluateJavascript(source: """
                  if (typeof document !== 'undefined') {
                    document.querySelector('html').setAttribute('lang', 'ja');
                    navigator.language = 'ja-JP';
                    navigator.languages = ['ja-JP', 'ja', 'en'];
                  }
                """);

                if (url.toString().contains('manaba.kic.kagoshima-u.ac.jp')) {
                  await Future.delayed(Duration(seconds: 2)); // ページロード待機

                  // JavaScriptで自動入力とログイン処理
                  await controller.evaluateJavascript(source: """
                    document.getElementById('login-username').value = '${credentials['username']}';
                    document.getElementById('login-password').value = '${credentials['password']}';
                    document.getElementById('btn-login').click();
                  """);
                }
              },
            );
          }
        },
    );
  }
}
