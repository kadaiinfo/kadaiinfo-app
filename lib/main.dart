//パッケージはpubspec.yamlに記述することでインポートできるようになります。
import 'package:flutter/material.dart';
//これはボトムナビゲーションバーをカスタマイズするためのパッケージです。
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
//これはFirebaseのメッセージングを使うためのパッケージです。
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart'; // UUIDを生成するためのパッケージ

//以下ようにしてファイルをインポートできます。
//mainが長くなったら別ファイルに切り分けて開発していくのがいいです。
import 'home_page.dart'; //トップぺージのファイルをインポート
import 'manaba_page.dart'; //manabaページのファイルをインポート
import 'contents_page.dart'; //コンテンツページのファイルをインポート
import 'setting_page.dart'; //設定ページのファイルをインポート

//ここはFlutterのおまじないです。
//main関数はアプリのエントリーポイントです。
//ここからアプリが始まります。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // FCM の通知権限リクエスト
  final messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  //print('User granted permission: ${settings.authorizationStatus}');

  // トークンを取得して表示（デバッグ用）
  String? fcmToken = await messaging.getToken();
  print('FCM TOKEN: $fcmToken');

  runApp(MyApp());
}

//ここもFlutterのおまじないです。
//MyAppクラスはアプリのルートとなるクラスです。
//StatelessWidgetを継承したクラスで、
//MaterialAppウィジェットを返すbuildメソッドを持っています。
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

//ここもFlutterのおまじないです。
//StatefulWidgetを継承したMainNavigationScreenクラスを作成します。
//_MainNavigationScreenState() は _MainNavigationScreenState クラスのインスタンスを作成します。
//このクラスは MainNavigationScreen ウィジェットの状態を管理します。
class MainNavigationScreen extends StatefulWidget {
  MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

//このクラスはアプリケーションのメインナビゲーションを管理し、
//ナビゲーションバーを使って異なるページ（HomePage、ContentsPage、ManabaPage、SettingsPage）に切り替えることができます。
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  //初期ページのインデックスを定義します。この変数がこのページの要です。
  //_をつけるのは、プライベート変数であることを示すためです。
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.getToken().then((String? token) {
      assert(token != null);
      print("FirebaseMessaging token: $token");
      saveTokenToFirestore(token!);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      saveTokenToFirestore(token);
    });
  }

  void saveTokenToFirestore(String token) {
    final String tokenId = Uuid().v4(); // 一意のIDを生成
    FirebaseFirestore.instance.collection('tokens').doc(tokenId).set({
      'token': token,
      'timestamp': FieldValue.serverTimestamp(), // 保存時刻を記録
    }, SetOptions(merge: true));
  }

  //0: HomePage
  //1: ContentsPage
  //2: ManabaPage
  //3: SettingsPage

  @override
  Widget build(BuildContext context) {
    Widget _body;

    // インデックスによって_bodyを切り替えられるようにswitch文にします
    // if文でもいいですが、switch文の方が見やすいです。
    //_bodyとするのは、_bodyが変数で、bodyがScaffoldのプロパティだからです。
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
      //エラーハンドリング
      default:
        _body = Center(child: Text('ページが見つかりません'));
        break;
    }

    // Scaffoldで画面を構成します。
    //3つの構造から成り立っています。
    return Scaffold(
      backgroundColor: Colors.white,

      //上部のバーの設定
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(0.0), // AppBarの高さを設定
        child: AppBar(
          backgroundColor: Colors.white, // AppBarの背景色を白に設定
          iconTheme: IconThemeData(color: Colors.black54), // アイコンの色を設定
          elevation: 0, // AppBarの影をなくす
        ),
      ),

      //bodyプロパティに_bodyを設定
      body: _body,

      //下部のバーの設定
      bottomNavigationBar: Padding(
        //デザイン部分
        padding: EdgeInsets.only(bottom: 16), // ナビゲーションバーの下に16の余白を追加
        child: CurvedNavigationBar(
          index: _currentIndex,
          height: 60,
          items: <Widget>[
            Icon(Icons.home, size: 30),
            Icon(Icons.widgets, size: 30),
            Icon(Icons.school, size: 30),
            Icon(Icons.settings, size: 30),
          ],
          color: Colors.white, // ナビゲーションバーの背景色
          backgroundColor: Colors.white,
          buttonBackgroundColor: Colors.white, // タブボタンの背景色
          animationDuration: Duration(milliseconds: 300),

          //処理部分
          //アイコンをタップしたときの処理
          onTap: (index) {
            setState(() {
              //タップしたインデックスを_currentIndexに代入することで、_bodyを切り替える
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
