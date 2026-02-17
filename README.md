# 🌀 GuruGuruCapture

> マウスをぐるぐるするだけでスクショ撮れるやつ。

---

## Inspiration

このアプリは [ナル先生](https://x.com/GOROman) さんの「クルクルミラクル」のアイデアに触発されて作成しました。

> マウスカーソルをクルクルすると、その範囲をAIが要約してくれるやつを作った。
> — [@GOROman](https://x.com/GOROman/status/2009250960867041584)

---

## なにこれ？

マウスをくるくる回すと、その軌跡の範囲を自動検出して
**調整可能なキャプチャUIを出してくれる** macOS常駐アプリ！

`Cmd+Shift+4` を毎回押すのダルくない？って人向け。

```
ぐるぐる🌀 → 全画面オーバーレイ表示 → ハンドルで範囲調整 → Enter で確定 → 保存！
```

---

## 動作環境

- macOS 13 Ventura 以降
- Swift 5.9 以降（Xcode Command Line Tools でOK）

---

## インストール

### リリース版を使う場合
1. [Releases](https://github.com/Shinichi-Ohki/GuruGuruCapture/releases) から `GuruGuruCapture.zip` をダウンロードして解凍
2. ターミナルで隔離属性を解除：
   ```bash
   xattr -rc /path/to/GuruGuruCapture.app
   ```
3. アプリケーションフォルダにコピー
4. 起動

### ソースからビルドする場合

```bash
# リポジトリをクローン
git clone git@github.com:Shinichi-Ohki/GuruGuruCapture.git
cd GuruGuruCapture

# ビルド
swift build -c release --build-path ./build

# アプリを作成（オプション）
# Info.plistとアイコンを設定した.appバンドルを作成可能
```

メニューバーに 🌀 が出たら起動成功！

---

## 初回起動時の権限設定

2つの権限が必要。どっちも許可しないと動かないから注意！

### 1. アクセシビリティ（必須）
グローバルなマウス監視に必要。

```
システム設定 → プライバシーとセキュリティ → アクセシビリティ
→ GuruGuruCapture をオンにする
```

### 2. 画面収録（必須）
キャプチャに必要。macOS 14以降は初回起動時に自動でダイアログが出る。

```
システム設定 → プライバシーとセキュリティ → 画面収録
→ GuruGuruCapture をオンにする
```

---

## 使い方

### Step 1: ぐるぐる
マウスカーソルをキャプチャしたい範囲でくるくる回す（約1周半で発動）。

### Step 2: 範囲調整
全画面が暗くなって、軌跡のバウンディングBoxが選択範囲として表示される。

| 操作 | 動作 |
|------|------|
| 🔵 ハンドルをドラッグ | 四隅・四辺のリサイズ |
| 内側をドラッグ | 選択範囲を移動 |
| `Enter` or ダブルクリック | **確定してキャプチャ！** |
| `Esc` or 右クリック | キャンセル |

### Step 3: 保存
- 📋 **クリップボード**にコピー（そのままペーストできる）
- 🖥️ 指定したフォルダに `GuruGuru_yyyyMMdd_HHmmss.png` で保存

---

## 設定

メニューバーの 🌀 をクリック → 「設定...」で設定画面を開けます。

### 保存先
- **ファイル + クリップボード** - 両方に保存（デフォルト）
- **ファイルのみ** - ファイルだけに保存
- **クリップボードのみ** - クリップボードだけにコピー

### 保存フォルダ
デフォルトはデスクトップ。任意のフォルダを指定可能。

---

## チューニング

`Sources/GuruGuruCapture/main.swift` の `SwirlDetector` 内のパラメータを調整できる。

```swift
private let windowDuration: TimeInterval = 1.4  // 判定ウィンドウ（秒）
private let triggerAngle: CGFloat = 2.5 * .pi   // 必要な回転量（450°）
private let minRadius: CGFloat = 30.0            // 最小回転半径(px)
```

- 誤爆しまくる → `minRadius` を上げる
- 反応しない → `triggerAngle` を下げる

---

## ログイン時に自動起動

```bash
# アプリをアプリケーションフォルダにコピー
cp -r GuruGuruCapture.app /Applications/

# システム設定 → 一般 → ログイン項目 から追加
```

---

## トラブルシューティング

**マウスぐるぐるしても反応しない**
→ アクセシビリティ権限を確認。権限付与後はアプリを再起動してね。

**キャプチャ画像が真っ黒になる**
→ 画面収録権限を確認。

**誤爆しすぎる**
→ `minRadius` を `50` くらいに上げてみて。

---

## 開発

### ビルド

```bash
swift build -c release --build-path ./build
```

### アプリバンドル作成

```bash
# 構造作成
mkdir -p GuruGuruCapture.app/Contents/{MacOS,Resources}

# バイナリコピー
cp build/release/GuruGuruCapture GuruGuruCapture.app/Contents/MacOS/

# Info.plist作成（別途必要）

# コード署名（自己署名証明書が必要）
codesign --force --deep --sign "GuruGuruCapture" GuruGuruCapture.app
```

---

## ライセンス

MIT License — 好きに使ってどうぞ。

---

*Made with 🌀*
