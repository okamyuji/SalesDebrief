# SalesDebrief

SalesDebriefは、フィールドセールス担当者が顧客訪問の直後に音声でデブリーフィングを記録し、構造化された訪問メモとフォローアップメールの下書きを3分以内に作成できるiPhoneアプリです。会議の録音ツールとは異なり、訪問後に一人で話す短い音声メモを入力として受け取り、次の商談につながるアクション管理を手早く完了することを目的としています。

## 主な機能

- 音声を録音してAppleの音声認識機能によりオンデバイスで文字起こしします
- 文字起こし結果から訪問内容を自動的に構造化フィールドへ分類します
- 構造化された訪問データをもとにフォローアップメールの下書きを生成します
- メールのトーンはニュートラル、ウォームコンサルティング、ダイレクトの3種類から選択できます
- 訪問履歴はアカウント名やキーワードで検索できます
- すべての処理はデバイス上で完結しており、ネットワーク接続を必要としません

## 日常的な使い方

1. ホーム画面から「新規デブリーフ」をタップします
2. 録音ボタンを押しながら30〜90秒の音声を吹き込みます
3. 文字起こし結果を確認します
4. 自動抽出された構造化フィールドを必要に応じて編集して保存します
5. 「フォローアップ生成」をタップしてメール下書きを作成します
6. メール下書きをiOSの共有機能でそのまま送信します

音声入力には以下のガイドフレーズを使うと自動抽出の精度が向上します。

``` text
Visited [アカウント名]. Spoke with [担当者名]. Goal was [目的]. What happened was [概要].
Main concern was [懸念点]. Competitor mentioned was [競合]. Next action is [次のアクション].
Follow-up by [期日].
```

## アーキテクチャ

このアプリはiOSアプリ本体と、ビジネスロジックを切り出したSwiftパッケージで構成されています。

```shell
SalesDebrief/
├── App/                # エントリポイントと依存注入コンテナ
├── Features/           # 画面単位のViewとViewModel
│   ├── Capture/        # 録音と文字起こし画面
│   ├── Recap/          # 訪問レポート編集画面
│   ├── EmailDraft/     # メール下書き画面
│   ├── History/        # 訪問履歴画面
│   ├── Home/           # ホーム画面
│   └── Settings/       # 設定画面
├── Services/           # 音声録音と音声認識のサービス層
├── Persistence/        # SwiftDataによるローカル永続化
└── Supporting/         # ロガーなどの補助コード

Packages/SalesDebriefCore/
├── Sources/
│   └── SalesDebriefCore/
│       ├── Models/               # データモデル
│       └── Services/
│           ├── RecapParser.swift           # 文字起こしから構造化データへの変換
│           └── EmailDraftGenerator.swift   # メール下書きの生成
└── Tests/
    └── SalesDebriefCoreTests/    # ユニットテスト
```

## 使用技術

| 技術 | 用途 |
| --- | ---- |
| Swift 6.0 / SwiftUI | アプリ本体の実装 |
| SwiftData | ローカルデータの永続化 |
| SFSpeechRecognizer | オンデバイス音声認識 |
| AVFoundation | 音声の録音とファイル処理 |
| StoreKit | サブスクリプションの管理 |

## 必要環境

- Xcode 16以上
- iOS 17以上を搭載したiPhone

## ビルド方法

このプロジェクトはxcodegenでXcodeプロジェクトファイルを管理しています。xcodegenをインストールしていない場合は以下を実行してください。

```bash
brew install xcodegen
```

インストール後、プロジェクトルートで以下を実行するとXcodeプロジェクトファイルが生成されます。

```bash
xcodegen generate
```

生成された`SalesDebrief.xcodeproj`をXcodeで開き、シミュレーターまたは実機でビルドします。

## 料金プラン

無料プランでは最大30件のデブリーフを作成できます。有料プランに切り替えるとデブリーフ数が無制限になり、メールトーンの選択肢、フォローアップ期日フィルタ、CSVエクスポート、アカウントピン留め機能が追加されます。
