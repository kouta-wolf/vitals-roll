import { useCallback, useEffect, useRef, useState } from "react"
import { toSnapshot } from "../domain/combatState"
import type { CombatState } from "../domain/combatState"

export type SaveStatus = "saved" | "saving" | "unsaved"

// 操作が止まってからこれだけ待ってまとめて送る
export const DEBOUNCE_MS = 2000
// 操作が続いていても、これ以上は未保存のまま放置しない
export const MAX_WAIT_MS = 15000
// サーバ側の一時的な失敗に対する再試行間隔
export const RETRY_MS = 5000

/**
 * 戦闘状態をデバウンスしてサーバへ書き戻す。
 *
 * 失敗しても楽観的更新はロールバックしない（#136 の決定）。戦闘中にチェックが
 * 勝手に戻るのは「セッションが止まる」のを悪化させるため、未保存であることを
 * 示して再試行する。
 */
export function useCombatStateSave(saveUrl: string, csrfToken: string, state: CombatState): SaveStatus {
  const [status, setStatus] = useState<SaveStatus>("saved")

  // 常に最新の状態を送るため、クロージャに閉じ込めず ref で参照する
  const latest = useRef(state)
  latest.current = state

  const savedRevision = useRef(state.revision)
  const timer = useRef<number | null>(null)
  const pendingSince = useRef<number | null>(null)

  // sendBeacon はヘッダを付けられないため、CSRFトークンはボディへ入れる。
  // fetch 経路でも同じボディを使う（サーバ側の permit が余分なキーを無視する）
  const buildBody = useCallback(
    () => JSON.stringify({ ...toSnapshot(latest.current), authenticity_token: csrfToken }),
    [csrfToken]
  )

  const scheduleRetry = useCallback((run: () => void) => {
    window.setTimeout(run, RETRY_MS)
  }, [])

  const save = useCallback(async (): Promise<void> => {
    const revision = latest.current.revision
    if (revision === savedRevision.current) return

    setStatus("saving")

    try {
      const response = await fetch(saveUrl, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
        body: buildBody()
      })

      if (!response.ok) {
        setStatus("unsaved")
        // 4xx は内容が変わらない限り何度送っても同じ結果になるため繰り返さない
        if (response.status >= 500) scheduleRetry(() => void save())
        return
      }

      savedRevision.current = revision
      // 保存中にさらに操作されていた場合は未保存のまま（直後のデバウンスで送られる）
      setStatus(latest.current.revision === revision ? "saved" : "unsaved")
    } catch {
      // 回線断など。復帰したら送れる可能性があるため再試行する
      setStatus("unsaved")
      scheduleRetry(() => void save())
    }
  }, [buildBody, csrfToken, saveUrl, scheduleRetry])

  // 変更が入ったらデバウンスして保存する。操作が続く場合も MAX_WAIT_MS で打ち切る
  useEffect(() => {
    if (state.revision === savedRevision.current) return

    setStatus("unsaved")
    pendingSince.current ??= Date.now()

    const waited = Date.now() - pendingSince.current
    const delay = Math.max(0, Math.min(DEBOUNCE_MS, MAX_WAIT_MS - waited))

    if (timer.current !== null) window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => {
      pendingSince.current = null
      void save()
    }, delay)

    return () => {
      if (timer.current !== null) window.clearTimeout(timer.current)
    }
  }, [state.revision, save])

  // ページを離れる瞬間の取りこぼしを防ぐ。
  // Turbo Drive の遷移では pagehide が発火しないため turbo:before-visit も購読する。
  // 同期的に投げ切る必要があるので fetch ではなく sendBeacon を使う
  useEffect(() => {
    const flush = (): void => {
      if (latest.current.revision === savedRevision.current) return

      const sent = navigator.sendBeacon(saveUrl, new Blob([ buildBody() ], { type: "application/json" }))
      if (sent) savedRevision.current = latest.current.revision
    }

    document.addEventListener("turbo:before-visit", flush)
    window.addEventListener("pagehide", flush)

    return () => {
      document.removeEventListener("turbo:before-visit", flush)
      window.removeEventListener("pagehide", flush)
    }
  }, [buildBody, saveUrl])

  return status
}
