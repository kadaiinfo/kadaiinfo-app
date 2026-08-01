import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'home_page.dart';
import 'gourmet_page.dart';
import 'contents_page.dart';
import 'club_page.dart';
import 'setting_page.dart';
import 'widgets/liquid_glass.dart';
import 'widgets/liquid_glass_nav_bar.dart';

/// ボトムナビゲーションバーのデザイン切り替えスイッチ。
///
/// true  : Liquid Glass 風のフローティングバー（lib/widgets/liquid_glass_nav_bar.dart）
/// false : 従来の CurvedNavigationBar
///
/// 元のデザインに戻したいときは、この 1 行を false にするだけでよい。
const bool kUseLiquidGlassNavBar = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      home: MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  static const int timeoutDuration = 1800000; // 30分（ミリ秒）

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFirebase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// **アプリのライフサイクルが変わった時の処理**
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _checkTimeoutAndReset();
    } else if (state == AppLifecycleState.paused) {
      await _saveLastActiveTime();
    }
  }

  /// **Firebaseの初期化**
  Future<void> _initializeFirebase() async {
    FirebaseMessaging.instance.getToken().then((String? token) {
      if (token != null) {
        saveTokenToFirestore(token);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      saveTokenToFirestore(token);
    });
  }

  /// **Firebase トークンを Firestore に保存**
  void saveTokenToFirestore(String token) {
    final String tokenId = Uuid().v4();
    FirebaseFirestore.instance.collection('tokens').doc(tokenId).set({
      'token': token,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// **最後のアクティブ時刻を保存**
  Future<void> _saveLastActiveTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_active_time', currentTime);
  }

  /// **アプリ再開時に一定時間が経過していたら case 0 に戻す**
  Future<void> _checkTimeoutAndReset() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastActiveTime = prefs.getInt('last_active_time');
    int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (lastActiveTime == null) {
      await prefs.setInt('last_active_time', currentTime);
      return;
    }

    if (currentTime - lastActiveTime > timeoutDuration) {
      setState(() {
        _currentIndex = 0; // case 0 に戻す
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget _body;
    switch (_currentIndex) {
      case 0:
        _body = HomePage();
        break;
      case 1:
        _body = ContentsPage();
        break;
      case 2:
        _body = GourmetPage(onBack: () => _onNavTap(0));
        break;
      case 3:
        _body = ClubPage();
        break;
      case 4:
        _body = SettingsPage();
        break;
      default:
        _body = Center(child: Text('ページが見つかりません'));
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(0.0),
        child: AppBar(
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black54),
          elevation: 0,
        ),
      ),
      // Liquid Glass は背面をぼかすため、body をバーの下まで伸ばす必要がある。
      extendBody: kUseLiquidGlassNavBar,
      body: _body,
      bottomNavigationBar: _showNavBar
          ? (kUseLiquidGlassNavBar
              ? _buildLiquidGlassNavBar()
              : _buildCurvedNavBar())
          : null,
    );
  }

  /// グルメページは全画面で見せたいのでナビゲーションを出さない。
  /// 代わりにページ左上のガラスの戻るボタンからホームへ戻る。
  bool get _showNavBar => _currentIndex != _gourmetIndex;

  static const int _gourmetIndex = 2;

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Liquid Glass 風のフローティングバー。
  Widget _buildLiquidGlassNavBar() {
    return LiquidGlassNavBar(
      currentIndex: _currentIndex,
      onTap: _onNavTap,
      // ガラスの透明度。Apple が用意しているのは regular と clear の 2 段階だけ。
      // clear は実機だと背面が透けすぎてラベルが読みにくくなるため regular にする
      // （シミュレータは UIGlassEffect を忠実に再現しないので判断材料にしない）。
      glassStyle: LiquidGlassStyle.regular,
      items: const <LiquidGlassNavItem>[
        LiquidGlassNavItem(icon: Icons.home, label: 'ホーム'),
        LiquidGlassNavItem(icon: Icons.menu_book, label: 'フリーペーパー'),
        LiquidGlassNavItem(icon: Icons.restaurant, label: 'グルメ'),
        LiquidGlassNavItem(icon: Icons.sports_baseball, label: 'サークル'),
      ],
    );
  }

  /// 変更前のデザイン。kUseLiquidGlassNavBar を false にするとこちらが使われる。
  Widget _buildCurvedNavBar() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: CurvedNavigationBar(
        index: _currentIndex,
        height: 60,
        items: <Widget>[
          Icon(Icons.home, size: 30),
          Icon(Icons.menu_book, size: 30),
          Icon(Icons.restaurant, size: 30),
          Icon(Icons.sports_baseball, size: 30),
        ],
        color: Colors.white,
        backgroundColor: Colors.white,
        buttonBackgroundColor: Colors.white,
        animationDuration: Duration(milliseconds: 300),
        onTap: _onNavTap,
      ),
    );
  }
}
