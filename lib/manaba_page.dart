import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManabaPage extends StatefulWidget {
  @override
  _ManabaPageState createState() => _ManabaPageState();
}

class _ManabaPageState extends State<ManabaPage> {
  final String manabaUrl = 'https://manaba.kic.kagoshima-u.ac.jp/';
  late final InAppWebViewController _controller;
  final _storage = FlutterSecureStorage();

  // 入力されたクレデンシャルをセキュアストレージに保存し、コンソールに表示
  Future<void> _saveCredentials(String username, String password) async {
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'password', value: password);

    // 保存後の確認
    String? savedUsername = await _storage.read(key: 'username');
    String? savedPassword = await _storage.read(key: 'password');

    print('Saved Username: ${savedUsername ?? "Failed to save username"}');
    print('Saved Password: ${savedPassword ?? "Failed to save password"}');
  }

  // 保存されているクレデンシャルを取得
  Future<Map<String, String>> _getCredentials() async {
    String? username = await _storage.read(key: 'username');
    String? password = await _storage.read(key: 'password');
    return {
      'username': username ?? '',
      'password': password ?? '',
    };
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
              onWebViewCreated: (InAppWebViewController controller) {
                _controller = controller;
              },
              onLoadStop: (controller, url) async {
                if (url.toString().contains('manaba.kic.kagoshima-u.ac.jp')) {
                  await Future.delayed(Duration(seconds: 2)); // ページロード待機

                  // JavaScriptで自動入力とログイン処理
                  await controller.evaluateJavascript(source: """
                    document.getElementById('login-username').value = '${credentials['username']}';
                    document.getElementById('login-password').value = '${credentials['password']}';
                    document.getElementById('btn-login').click();
                  """);

                  // 保存されたクレデンシャルをコンソールに表示
                  await _saveCredentials(
                      credentials['username']!, credentials['password']!);
                }
              },
            );
          }
        },
      ),
    );
  }
}
