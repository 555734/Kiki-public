# 通信互換性

現在の協力wire versionは21、対戦wire versionは12です。アプリの `config/version` （0.9.9など）を接続時に比較していません。0.9.8と0.9.9は協力wire21であり、マーケティングversionが違うという理由だけで拒否される実装ではありません。ただし同じwire番号だけで全コンテンツの互換性が保証されるわけではありません。

協力HELLOはwire番号、固定Stage enum整数、役割、player ID、権利token、jump sequenceを送信します。ホストはwire番号が異なる接続を拒否します。0.9.6はwire20で、後のCoopRoom/session変更に伴って21になりました。アプリの番号を増やしただけで通信番号を増やすルールではありません。

EOS lobbyのstage_keyはルーム一覧の識別子で、HELLOのcontent交渉を置き換えません。既存Stage enum値は保存・通信契約であり、並べ替えてはいけません。

次に握手形式を変えるときは、新wire versionで次を導入します。

1. wire_protocol: メッセージ形式の互換性。
2. content_version と安定stage_key: 選択ステージの地形、entity ID、共有シミュレーション契約。
3. feature_flags: optional機能の共通部分を交渉。必須機能が欠ける場合は明示拒否。
4. 旧新クライアントの組合せ、未知stage、必要feature欠落、権利確認を契約テストで確認。

wireの一致判定を削除したり、未対応のstageを整数fallbackで開始する変更は行いません。content変更が同期シミュレーションを壊す場合もwire/contentの境界を確認して互換性を判定します。二端末の実プレイはリリース受け入れ項目A8で別途確認してください。
