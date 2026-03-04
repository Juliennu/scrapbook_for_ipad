# ScrapNotePad (iPad)

SwiftUI + PencilKitで作成した、iPad向けスクラップノートアプリです。

## できること

- ノートの作成・削除
- ページの追加・削除
- Apple Pencil / 指での手書き
- PencilKit標準ツール（ペン・消しゴム等）
- Undo / Redo
- ページ背景への写真貼り付け
- ノート内容のローカル保存（JSON）

## セットアップ

1. `xcodegen generate`
2. `ScrapNotePad.xcodeproj` をXcodeで開く
3. iPadシミュレータ or 実機で実行

## 補足

- 保存先はアプリの Documents 配下 `scrap_notebooks.json`
- 本実装は Paper のUI/体験を参考にした独自実装です（同一デザイン/完全複製ではありません）
