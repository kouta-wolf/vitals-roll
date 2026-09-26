// React に「ここはテスト環境なので act() を受け付けてよい」と伝えるフラグ。
// 設定しないと act() でラップしても "not configured to support act(...)" の警告が出る。
declare global {
  var IS_REACT_ACT_ENVIRONMENT: boolean
}

globalThis.IS_REACT_ACT_ENVIRONMENT = true

export {}
