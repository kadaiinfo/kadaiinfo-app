# 環境構築

## gitのインストール
gitをインストールしていない場合はインストールします。以下の手順に従ってインストルールを行ってください。
https://kinsta.com/jp/knowledgebase/install-git/


## flutterの環境構築方法（Docker環境）
Dockerを使用すると、ローカル環境を汚さずに開発環境を構築できます。

### 前提条件
- Dockerがインストールされていること

Dockerのインストール方法:
- Mac: [Docker Desktop for Mac](https://www.docker.com/ja-jp/)
- Windows: [Docker Desktop for Windows](https://www.docker.com/ja-jp/)

### Docker環境の構築手順

1. プロジェクトをクローン
```bash
git clone https://github.com/kadaiinfo/KADAI-INFO-STUDIO-APP.git
cd KADAI-INFO-STUDIO-APP
```

2. Dockerコンテナをビルド・起動
```bash
cd .devcontainer
docker-compose up -d --build
```

3. コンテナに入る
```bash
docker exec -it kadaiinfo_app_flutter /bin/bash
```

4. ワークスペースに移動して依存関係をインストール
```bash
cd workspace
flutter pub get
```

5. Flutterの環境確認
```bash
flutter doctor
```

### Docker環境での起動方法
コンテナ内でAndroidエミュレータを直接起動することはできませんが、以下の方法で開発できます:

- **VS Code Dev Containers（推奨）**: VS Codeの拡張機能「Dev Containers」を使用すると、自動的にコンテナ内で開発できます
- **ホスト側のエミュレータを使用**: ホスト側でエミュレータを起動し、コンテナからアクセスする

### よく使うDockerコマンド
```bash
# コンテナの起動
docker-compose up -d

# コンテナの停止
docker-compose down

# コンテナに入る
docker exec -it kadaiinfo_app_flutter /bin/bash

# コンテナのログを確認
docker-compose logs -f
```


## flutterの環境構築方法（ローカル環境）
### Windowsの場合<br>
https://zenn.dev/heyhey1028/books/flutter-basics/viewer/getting_started_windows

### Macの場合<br>
https://zenn.dev/heyhey1028/books/flutter-basics/viewer/getting_started_mac


## このコードの動かし方<br>
このプロジェクトを使って開発を始めるには、まずプロジェクトを自分のコンピュータにクローンする必要があります。

クローンが完了したら、プロジェクトディレクトリに移動します。
プロジェクトに必要な依存関係をインストールします。

```
% git clone https://github.com/kadaiinfo/KADAI-INFO-STUDIO-APP.git
% cd KADAI-INFO-STUDIO-APP
% flutter pub get
```
依存関係のインストールが完了したら、開発を始める準備が整いました。



### 起動方法<br>
シミュレータが起動した状態で以下のコマンドで実行することで、プロジェクトをシミュレータ上で起動できます。
```
% flutter run
```

以下のコマンドで、接続可能なデバイスを一覧表示することができます。
```
% flutter deveices
```

上記のコマンドで取得したデバイスIDを指定して実行することで、実機上で起動することもできます。
```
% flutter run -d "<デバイスID>"
```

# 開発の進め方
### ローカル開発する
1. まずはIssuesからIssueを立てるor引き受けます。右側のAssigneesのassign yourselfを押してください。
2. Assigneesの下の方にあるDevelopmentからbranchを作って作業してください。
3. 作業が一区切りついたら、コミットします。
    ```
    % git add .
    % git commit -m "<コミットメッセージ>"
    % git push origin <ブランチ名>
    ```
4. 全ての作業が終わったら、リポジトリの上部に黄色で表示されているCompere & pull requestを押します。プルリクを送ってください。
5. 誰かがコードを確認しておかしなところがなければMerge Pull requestを押して、マージします。
6. mainに戻ってpullします。
    ```
    % git checkout main 
    % git pull 
    ```
7. これでブランチで作業したものがmainに統合されます。

### ディレクトリ構造
基本的にlibの中にコードを書いていきます。<br>
```
lib
├── contents_page.dart //コンテンツページ
├── firebase_options.dart //firebaseの設定ページ
├── home_page.dart //トップページ
├── main.dart //main アプリの起動などを担うroot
├── manaba_page.dart // manabaページ
└── setting_page.dart //設定ページ
```

### パッケージ(プラグイン)のインストール方法
新たにパッケージ(プラグイン)をimportしたい場合、二つの操作をする必要があります。
1. pubspec.yamlファイルにパッケージ(プラグイン)を書き足す。
```
プラグイン名: バージョン指定d
```
2. ターミナルで、
```
flutter pub get
```
これで、ファイルでパッケージをインポートすることができます。<br>

上記の方法でもいいですが、以下のコマンドを打つことで、上記の二つの動作をコマンドで実行できます。
```
flutter pub add プラグイン名
```

### デプロイ作業
iOSの場合、AppleStoreConnectからデプロイします。Reviewを出して、審査が通ればリリースになります。デプロイした後にバグが見つかることが多いので、デプロイする際はいつでも元のバージョンに戻せるようにバックアップをとっておきましょう。<br>

# バージョンの指定
バージョンは、pubspec.yamlファイルに指定します。<br>
``1.5.0+11``の場合、<br>
・1.5.0はリリースのバージョン<br>
・11はビルド番号<br>

リリースのバージョンは以下のように運用してきます。

大幅なシステム改変に伴うアップデートの場合。<br>
```1.0.0→2.0.0```<br>
中規模なアップデートの場合。新規機能の追加など<br>
```1.0.0→1.1.0```<br>
小規模なアップデートやメンテナンス、バグ修正など<br>
```1.0.0→1.0.1```<br>

ビルド番号はバージョンに限らず、ビルドするたび(ストアにリリースするたび)に一つずつ上げていきます。<br>
```1→2→3```<br>

リリース番号とビルド番号を上げずにデプロイすることはできない？ので注意。<br>







