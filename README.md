# TypeTalk Backup Viewer

TypeTalkのAPIからメッセージ、添付ファイル、アイコンをダウンロードし、TypeTalk風の静的HTMLビューアを生成するツールです。
- Web APIからアクセスして、書き込みやDMをJSON形式のファイルとして指定したディレクトリ内に保存します
- ユーザー情報とアイコン情報も保存します
- 保存する情報は、APIアクセス権を設定したユーザーから見える範囲です（＝Web利用時に見える範囲と同じ）
- TypeTalk APIの仕様はこちら: https://developer.nulab.com/ja/docs/typetalk/

## 機能
- トピック／DMのメッセージを取得・保存
- 添付ファイル・アイコンのダウンロード
- 静的HTMLビュアーの自動生成（TypeTalk風UI）（作成中、未完成）

## 必要なもの
- Ruby 3.x（標準ライブラリのみで動作）
-- macOS Sequoia 15.0, ruby 3.1.4p223 (2023-03-30 revision 957bb7cb81) [arm64-darwin22] で動作確認済み
- `credentials.json`（認証情報）


## セットアップ
1. このリポジトリをクローンします。
2. `credentials.json` をプロジェクト直下に作成（サンプルあり）。
- TypeTalkアクセス権を指定する「TypeTalkトークン」の作成
「開発アプリケーション」ページ( https://typetalk.com/my/develop/applications )の「デベロッパー」項目から「新規アプリケーション」を作成
「アプリケーション名」（適当なものを指定）、「Client Credentials」を洗濯して、「作成」
作成したアプリケーションから「Client ID」と「Client Secret」の情報を credentials.json へ転記する
- アクセス対象を指定する「スペースキー」の取得
「開発アプリケーション」ページ( https://typetalk.com/my/develop/applications )の「プロフィール」項目から「スペースキー」をコピー
-> credentials.json 内に記載
3. スクリプト実行方法は以下のとおりです。

```bash
ruby get_allmessages.rb (backup先、省略時はbackup) (TypeTalkトークンのファイル名、省略時はcredentials.json)
ruby get_dm.rb (backup先、省略時はbackup) (TypeTalkトークンのファイル名、省略時はcredentials.json)
```

## 出力物
- backup/ ディレクトリにトピックごとのメッセージと添付ファイルが保存されます。
- backup/dm ディレクトリにDMメッセージと添付ファイルが保存されます。
- backup/index.html を開くとTypeTalk風のビュアーとして閲覧できます（オフライン対応）。（未完成）

