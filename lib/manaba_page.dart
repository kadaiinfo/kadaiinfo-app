import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ManabaPage extends StatefulWidget {
  @override
  _ManabaPageState createState() => _ManabaPageState();
}

class _ManabaPageState extends State<ManabaPage> {
  final String manabaUrl = 'https://manaba.kic.kagoshima-u.ac.jp/';
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.0),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              } else {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _getCredentials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else {
            final credentials = snapshot.data!;
            return InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(manabaUrl)), // 修正
              initialSettings: InAppWebViewSettings(
                userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1 Accept-Language: ja-JP,ja;q=0.9,en;q=0.8',
                supportZoom: true,
                javaScriptEnabled: true,
                preferredContentMode: UserPreferredContentMode.MOBILE,
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
                        var result = await _controller.evaluateJavascript(source: '''
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
      ),
    );
  }
}
