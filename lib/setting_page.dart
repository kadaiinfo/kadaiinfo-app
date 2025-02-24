// その他ページの管理をここで行います。
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(0.0), // AppBarの高さを設定
        child: AppBar(
          backgroundColor: Colors.white, // AppBarの背景色を白に設定
          iconTheme: IconThemeData(color: Colors.black54), // アイコンの色を設定
          elevation: 0, // AppBarの影をなくす
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [],
          ),
        ),
      ),

      //bodyプロパティにSettingsListを設定
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('このアプリについて'),
            tiles: [
              SettingsTile(
                title: const Text('KADAI INFOについて'),
                trailing: const Icon(Icons.launch),
                onPressed: (BuildContext context) async {
                  const url = 'https://kadaiinfo.com/about-us';
                  if (await canLaunch(url)) {
                    await launch(url);
                  }
                },
              ),
              SettingsTile(
                title: const Text('お問い合わせ'),
                trailing: const Icon(Icons.launch),
                onPressed: (BuildContext context) async {
                  const url = 'https://kadaiinfo.com/contact';
                  if (await canLaunch(url)) {
                    await launch(url);
                  }
                },
              ),
              SettingsTile(
                title: const Text('利用規約'),
                trailing: const Icon(Icons.launch),
                onPressed: (BuildContext context) async {
                  const url = 'https://kadaiinfo.com/privacy-policy';
                  if (await canLaunch(url)) {
                    await launch(url);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
