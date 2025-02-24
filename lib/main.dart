import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'manaba_page.dart';
import 'contents_page.dart';
import 'setting_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
        //print("FirebaseMessaging token: $token");
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
    //print("【アクティブ時間記録】$currentTime");
  }

  /// **アプリ再開時に一定時間が経過していたら case 0 に戻す**
  Future<void> _checkTimeoutAndReset() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastActiveTime = prefs.getInt('last_active_time');
    int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (lastActiveTime == null) {
      //print("【初回起動】現在時刻を保存: $currentTime");
      await prefs.setInt('last_active_time', currentTime);
      return;
    }

    //print("【チェック】前回のアクティブ時刻: $lastActiveTime");
    //print("【チェック】現在の時刻: $currentTime");
    //print("【チェック】経過時間: ${currentTime - lastActiveTime} ミリ秒");

    if (currentTime - lastActiveTime > timeoutDuration) {
      //print("【自動遷移】10分以上経過: HomePage に戻る");
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
        _body = ManabaPage();
        break;
      case 3:
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
      body: _body,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: CurvedNavigationBar(
          index: _currentIndex,
          height: 60,
          items: <Widget>[
            Icon(Icons.home, size: 30),
            Icon(Icons.widgets, size: 30),
            Icon(Icons.school, size: 30),
            Icon(Icons.settings, size: 30),
          ],
          color: Colors.white,
          backgroundColor: Colors.white,
          buttonBackgroundColor: Colors.white,
          animationDuration: Duration(milliseconds: 300),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
