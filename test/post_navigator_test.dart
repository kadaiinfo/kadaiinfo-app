// PostNavigator の位置計算のテスト。
//
// WebView を動かさずに、一覧の取得結果を直接流し込んで確かめる。
// ページをまたぐ前後の解決はここでしか確認しづらいので、
// 一覧の並びは実際の /posts?page=N から取ったものを使っている。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:webview/post_navigator.dart';

void main() {
  // 実際の並び（2026 年 8 月時点）。1 ページ 12 件。
  const List<String> page1 = <String>[
    'T45_N8ANRlgq',
    'xfM3spTFO',
    'Z2gVnxM7yMpW',
    'kadai_onehand',
    'upN-KtwuD',
    'inter_view',
    'kadaisei_kiroku1',
    'interview-info30',
    'J1n282LxM',
    'kagoshima_pancake',
    'eeckBoTWsYcD',
    '7jX8r0KMyQF',
  ];
  const List<String> page2 = <String>[
    'kagoshima_cheesecake',
    'eigataisho2025',
    'yuruyuru_asakatsu',
    'gourmet_information',
    'kadaisei_omoidenokyoku',
    'event_kadaiclub',
    'about_kadaiinfo',
    'yorontabi',
    'kadai_tatekan2026',
    'sotsugyosnap2026',
    'strawberry_kagoshima',
    'juken_start',
  ];

  void feed(PostNavigator navigator, int page, List<String> slugs) {
    navigator.handleChannelMessage(
      jsonEncode(<String, Object>{'page': page, 'slugs': slugs}),
    );
  }

  void open(PostNavigator navigator, String slug) {
    navigator.handleUrl('https://kadaiinfo.com/posts/$slug');
  }

  test('一覧の途中の記事は前後どちらにも進める', () {
    final PostNavigator navigator = PostNavigator();
    feed(navigator, 1, page1);
    open(navigator, page1[3]);

    expect(navigator.isPostPage, isTrue);
    expect(navigator.newerSlug, page1[2]);
    expect(navigator.olderSlug, page1[4]);
  });

  test('最新の記事には新しい方向の行き先が無い', () {
    final PostNavigator navigator = PostNavigator();
    feed(navigator, 1, page1);
    open(navigator, page1.first);

    expect(navigator.hasNewer, isFalse);
    expect(navigator.olderSlug, page1[1]);
  });

  test('ページの境目で隣のページの記事につながる', () {
    final PostNavigator navigator = PostNavigator();
    feed(navigator, 1, page1);
    feed(navigator, 2, page2);

    // 1 ページ目の最後 → 2 ページ目の先頭
    open(navigator, page1.last);
    expect(navigator.olderSlug, page2.first);

    // 2 ページ目の先頭 → 1 ページ目の最後
    open(navigator, page2.first);
    expect(navigator.newerSlug, page1.last);
  });

  test('先に 2 ページ目だけ取得していても位置がずれない', () {
    // 一覧の途中のページから記事に入った場合。1 ページ目は未取得でも、
    // ページ番号から通し番号を出しているので 2 ページ目の中では前後が分かる。
    final PostNavigator navigator = PostNavigator();
    feed(navigator, 2, page2);
    open(navigator, page2[5]);

    expect(navigator.newerSlug, page2[4]);
    expect(navigator.olderSlug, page2[6]);
  });

  test('最終ページの末尾には古い方向の行き先が無い', () {
    final PostNavigator navigator = PostNavigator();
    // 12 件に満たないページが来たらそこが最終ページ。
    feed(navigator, 1, page1.sublist(0, 5));
    open(navigator, page1[4]);

    expect(navigator.newerSlug, page1[3]);
    expect(navigator.hasOlder, isFalse);
  });

  test('記事ページ以外では前後ボタンを出さない', () {
    final PostNavigator navigator = PostNavigator();
    feed(navigator, 1, page1);

    navigator.handleUrl('https://kadaiinfo.com/posts');
    expect(navigator.isPostPage, isFalse);

    navigator.handleUrl('https://kadaiinfo.com/');
    expect(navigator.isPostPage, isFalse);

    navigator.handleUrl('https://kadaiinfo.com/posts?page=3');
    expect(navigator.isPostPage, isFalse);

    // 別ドメインへ出たときも同じ。
    navigator.handleUrl('https://gourmet.kadaiinfo.com/posts/abc');
    expect(navigator.isPostPage, isFalse);
  });

  test('階層を持つ記事 URL も記事として扱う', () {
    final PostNavigator navigator = PostNavigator();
    feed(navigator, 1, <String>['sp/pizza_coffee', ...page1.sublist(0, 3)]);
    navigator.handleUrl('https://kadaiinfo.com/posts/sp/pizza_coffee');

    expect(navigator.isPostPage, isTrue);
    expect(navigator.olderSlug, page1.first);
  });

  test('取得に失敗した一覧は位置の判定に使わない', () {
    final PostNavigator navigator = PostNavigator();
    navigator.handleChannelMessage(
      jsonEncode(<String, Object>{'page': 1, 'error': true}),
    );
    open(navigator, page1[3]);

    expect(navigator.isPostPage, isTrue);
    expect(navigator.hasNewer, isFalse);
    expect(navigator.hasOlder, isFalse);
  });
}
