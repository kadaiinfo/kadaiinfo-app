// 記事ページ（https://kadaiinfo.com/posts/XXX）を開いている間だけ、
// 投稿順で前後の記事へ移動できるようにするための状態。
//
// 記事の並び順は WebView の中から同一オリジンで /posts?page=N を fetch して
// 取り出している。WebView はすでに kadaiinfo.com のオリジンにいるので CORS を
// 気にする必要がなく、microCMS の API キーをアプリに持たせずに済む
// （アプリのバイナリに入れたキーは取り出せてしまう上に、差し替えるには
// ストア更新を待つしかない）。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PostNavigator extends ChangeNotifier {
  /// WebView 側から取得結果を受け取る JavaScript チャンネルの名前。
  static const String channelName = 'KadaiPostOrder';

  static const String _origin = 'https://kadaiinfo.com';
  static const String _host = 'kadaiinfo.com';

  /// /posts?page=N が 1 ページに並べる記事数。
  /// 記事の位置を通し番号で扱うのにこの値を使うため、サイト側の表示件数を
  /// 変えたらここも合わせる必要がある。
  static const int pageSize = 12;

  /// 位置が分からない記事を開いたときに、何ページ目まで遡って探すか。
  /// 一覧から記事に入った場合はそのページを先読みしてあるので、ここが効くのは
  /// 通知や外部リンクから記事に直接飛んできたときだけ。
  static const int maxProbePages = 6;

  WebViewController? _controller;

  /// 取得済みの一覧。キーはページ番号（1 始まり）、値はそのページの記事スラッグ。
  final Map<int, List<String>> _pages = <int, List<String>>{};

  /// fetch を投げたが結果がまだ返っていないページ番号。
  final Set<int> _requested = <int>{};

  /// 最終ページの番号。記事数が 1 ページに満たないページを見つけると確定する。
  int? _lastPage;

  String? _currentSlug;
  String? _newerSlug;
  String? _olderSlug;

  /// いま記事ページを開いているか。ボトムバーの出し分けに使う。
  bool get isPostPage => _currentSlug != null;

  /// 1 つ新しい記事（一覧で 1 つ上にある記事）のスラッグ。無ければ null。
  String? get newerSlug => _newerSlug;

  /// 1 つ古い記事（一覧で 1 つ下にある記事）のスラッグ。無ければ null。
  String? get olderSlug => _olderSlug;

  bool get hasNewer => _newerSlug != null;

  bool get hasOlder => _olderSlug != null;

  /// 記事ページを開いているのに前後が確定せず、まだ一覧を探している最中か。
  /// ボタンを「押せない」ではなく「読み込み中」として見せるために使う。
  bool get isResolving =>
      isPostPage && _requested.isNotEmpty && !hasNewer && !hasOlder;

  /// WebView を紐づける。ページごとにコントローラが作り直されるので、
  /// 表示中のページのものだけを保持する。
  void attach(WebViewController controller) {
    _controller = controller;
    _clearPosition();
  }

  /// 紐づけを外す。タブを切り替えたときに古いページから呼ばれるが、
  /// 新しいページの attach が先に走っている場合があるので、
  /// 自分が持っているコントローラのときだけ外す。
  void detach(WebViewController controller) {
    if (!identical(_controller, controller)) {
      return;
    }
    _controller = null;
    _clearPosition();
  }

  /// WebView の表示 URL が変わったときに呼ぶ。
  void handleUrl(String url) {
    final String? slug = _postSlugOf(url);
    if (slug != _currentSlug) {
      _currentSlug = slug;
      _newerSlug = null;
      _olderSlug = null;
    }

    // 一覧を見ている間にその並びを取っておく。次に記事へ入ったとき、
    // 追加の通信なしで前後が確定する。
    final int? listPage = _listPageOf(url);
    if (listPage != null) {
      _requestPage(listPage);
      _requestPage(listPage + 1);
      if (listPage > 1) {
        _requestPage(listPage - 1);
      }
    }

    _resolve();
  }

  /// WebView 側の fetch から届いた一覧を取り込む。
  void handleChannelMessage(String message) {
    final Object? decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final Object? page = decoded['page'];
    if (page is! int) {
      return;
    }
    _requested.remove(page);

    // 取得に失敗したページは、次にまた必要になったときに取り直す。
    if (decoded['error'] == true) {
      _resolve();
      return;
    }

    final Object? slugs = decoded['slugs'];
    if (slugs is! List) {
      _resolve();
      return;
    }

    final List<String> parsed = slugs.whereType<String>().toList();
    if (parsed.isEmpty) {
      // 記事が 1 件も無いページ。1 つ手前が最終ページということになる。
      _lastPage = page - 1;
      _resolve();
      return;
    }

    if (parsed.length < pageSize) {
      _lastPage = page;
    }

    // 一覧に想定より多くのリンクが並ぶようになった場合に位置がずれないよう、
    // 通し番号の計算に使う件数だけを取り込む。
    _pages[page] =
        parsed.length > pageSize ? parsed.sublist(0, pageSize) : parsed;

    _resolve();
  }

  /// 1 つ新しい記事へ移動する。
  Future<void> goNewer() => _go(_newerSlug);

  /// 1 つ古い記事へ移動する。
  Future<void> goOlder() => _go(_olderSlug);

  /// サイトのトップへ戻る。
  Future<void> goHome() async {
    await _controller?.loadRequest(Uri.parse('$_origin/'));
  }

  /// 記事ページの URL か。上部バーの戻るボタンの出し分けに使う。
  static bool isPostUrl(String url) => _postSlugOf(url) != null;

  Future<void> _go(String? slug) async {
    final WebViewController? controller = _controller;
    if (slug == null || controller == null) {
      return;
    }
    // loadRequest なので WebView の履歴に積まれる。左上の戻るボタンや
    // 画面端のスワイプで元の記事に戻れる。
    await controller.loadRequest(Uri.parse('$_origin/posts/$slug'));
  }

  void _clearPosition() {
    _currentSlug = null;
    _newerSlug = null;
    _olderSlug = null;
    // 取得済みの一覧はページをまたいでも使えるので捨てない。
    // 返ってこないまま残った要求だけ畳む。
    _requested.clear();
    notifyListeners();
  }

  /// いま開いている記事の前後を求め、足りない一覧があれば取りに行く。
  void _resolve() {
    final String? slug = _currentSlug;
    if (slug == null) {
      notifyListeners();
      return;
    }

    final int? index = _indexOf(slug);
    if (index == null) {
      // 位置が分からない。まだ見ていない一覧を 1 ページずつ探す。
      final int? probe = _nextProbePage();
      if (probe != null) {
        _requestPage(probe);
      }
      _newerSlug = null;
      _olderSlug = null;
      notifyListeners();
      return;
    }

    _newerSlug = _slugAt(index - 1);
    _olderSlug = _slugAt(index + 1);

    // 記事がページの端にあると隣のページを見ないと前後が分からない。
    if (index > 0 && _newerSlug == null) {
      _requestPage(_pageOf(index - 1));
    }
    if (_olderSlug == null) {
      _requestPage(_pageOf(index + 1));
    }

    notifyListeners();
  }

  /// 通し番号からスラッグを引く。未取得のページなら null。
  String? _slugAt(int index) {
    if (index < 0) {
      return null;
    }
    final List<String>? page = _pages[_pageOf(index)];
    if (page == null) {
      return null;
    }
    final int offset = index % pageSize;
    return offset < page.length ? page[offset] : null;
  }

  /// スラッグの通し番号を引く。未取得のページにある記事なら null。
  int? _indexOf(String slug) {
    for (final MapEntry<int, List<String>> entry in _pages.entries) {
      final int offset = entry.value.indexOf(slug);
      if (offset >= 0) {
        return (entry.key - 1) * pageSize + offset;
      }
    }
    return null;
  }

  int _pageOf(int index) => index ~/ pageSize + 1;

  /// 位置探索で次に見るページ。上限まで見尽くしたら null。
  int? _nextProbePage() {
    for (int page = 1; page <= maxProbePages; page++) {
      if (_lastPage != null && page > _lastPage!) {
        return null;
      }
      if (!_pages.containsKey(page) && !_requested.contains(page)) {
        return page;
      }
    }
    return null;
  }

  /// 一覧を WebView 側で取得させる。取得済み・取得中・範囲外なら何もしない。
  void _requestPage(int page) {
    if (page < 1 || _pages.containsKey(page) || _requested.contains(page)) {
      return;
    }
    if (_lastPage != null && page > _lastPage!) {
      return;
    }
    final WebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    _requested.add(page);
    controller.runJavaScript(_fetchScript(page));
  }

  /// 一覧の HTML から記事スラッグを順番どおりに抜き出して送り返す。
  static String _fetchScript(int page) {
    final String path = page <= 1 ? '/posts' : '/posts?page=$page';
    return '''
(function () {
  fetch('$path', { credentials: 'same-origin' })
    .then(function (res) {
      if (!res.ok) { throw new Error(res.status); }
      return res.text();
    })
    .then(function (html) {
      var slugs = [];
      var re = /href="\\/posts\\/([^"#?]+)"/g;
      var m;
      while ((m = re.exec(html)) !== null) {
        if (slugs.indexOf(m[1]) === -1) { slugs.push(m[1]); }
      }
      $channelName.postMessage(JSON.stringify({ page: $page, slugs: slugs }));
    })
    .catch(function () {
      $channelName.postMessage(JSON.stringify({ page: $page, error: true }));
    });
})();
''';
  }

  /// 記事ページなら slug を返す。それ以外は null。
  static String? _postSlugOf(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host != _host) {
      return null;
    }
    final List<String> segments = uri.pathSegments;
    if (segments.length < 2 || segments.first != 'posts') {
      return null;
    }
    // /posts/sp/xxx のように階層を持つ記事があるので、残り全部をつなぐ。
    return segments.sublist(1).join('/');
  }

  /// 記事一覧ページならページ番号を返す。それ以外は null。
  static int? _listPageOf(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host != _host) {
      return null;
    }
    final List<String> segments = uri.pathSegments;
    if (segments.length != 1 || segments.first != 'posts') {
      return null;
    }
    return int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
  }
}
