import type { SaveStatus } from "./useCombatStateSave"

const LABELS: Record<SaveStatus, string> = {
  saved: "保存済み",
  saving: "保存中…",
  unsaved: "未保存",
  retrying: "未保存（再試行中）",
  // 4xx は内容が変わらない限り何度送っても同じ結果になるため再試行しない。
  // 「再試行中」と出すと放置すれば保存されると誤解させる
  failed: "保存に失敗しました"
}

const STYLES: Record<SaveStatus, string> = {
  saved: "text-gray-400",
  saving: "text-gray-500",
  unsaved: "text-gray-500",
  retrying: "text-amber-600 font-medium",
  failed: "text-red-600 font-medium"
}

// 楽観的更新のため、保存の成否は画面の状態からは分からない。
// 失敗してもロールバックしない方針（#136）なので、未保存であることを明示する
export function SaveStatusBadge({ status }: { status: SaveStatus }) {
  return <span className={`text-xs ${STYLES[status]}`}>{LABELS[status]}</span>
}
