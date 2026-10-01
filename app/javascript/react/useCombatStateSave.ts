import { useCallback, useEffect, useRef, useState } from "react"
import { toSnapshot } from "../domain/combatState"
import type { CombatState } from "../domain/combatState"

// unsaved: 変更あり（デバウンス待ち） / retrying: 失敗したが再試行する
// failed: 失敗して再試行しない（4xx。内容が変わらない限り結果は同じ）
export type SaveStatus = "saved" | "saving" | "unsaved" | "retrying" | "failed"

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
  const [ status, setStatus ] = useState<SaveStatus>("saved")

  // 常に最新の状態を送るため、クロージャに閉じ込めず ref で参照する
  const latest = useRef(state)
  latest.current = state

  const savedRevision = useRef(state.revision)
  const debounceTimer = useRef<number | null>(null)
  const retryTimer = useRef<number | null>(null)
  const pendingSince = useRef<number | null>(null)

  // sendBeacon はヘッダを付けられないため、CSRFトークンはボディへ入れる。
  // fetch 経路でも同じボディを使う（サーバ側の permit が余分なキーを無視する）
  const buildBody = useCallback(
    () => JSON.stringify({ ...toSnapshot(latest.current), authenticity_token: csrfToken }),
    [csrfToken]
  )

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
        // 4xx は内容が変わらない限り何度送っても同じ結果になるため繰り返さない
        if (response.status >= 500) {
          setStatus("retrying")
          scheduleRetry()
        } else {
          setStatus("failed")
        }
        return
      }

      savedRevision.current = revision
      // 保存中にさらに操作されていた場合は未保存のまま（直後のデバウンスで送られる）
      setStatus(latest.current.revision === revision ? "saved" : "unsaved")
    } catch {
      // 回線断など。復帰したら送れる可能性があるため再試行する
      setStatus("retrying")
      scheduleRetry()
    }

    // 再試行は常に1本に保つ。追跡しないと障害中に操作が続くたびチェーンが増殖し、
    // 古いスナップショットが後着して新しい状態を上書きし得る
    function scheduleRetry(): void {
      if (retryTimer.current !== null) window.clearTimeout(retryTimer.current)
      retryTimer.current = window.setTimeout(() => {
        retryTimer.current = null
        void save()
      }, RETRY_MS)
    }
  }, [ buildBody, csrfToken, saveUrl ])

  // 変更が入ったらデバウンスして保存する。操作が続く場合も MAX_WAIT_MS で打ち切る
  useEffect(() => {
    if (state.revision === savedRevision.current) return

    setStatus("unsaved")
    pendingSince.current ??= Date.now()

    const waited = Date.now() - pendingSince.current
    const delay = Math.max(0, Math.min(DEBOUNCE_MS, MAX_WAIT_MS - waited))

    if (debounceTimer.current !== null) window.clearTimeout(debounceTimer.current)
    debounceTimer.current = window.setTimeout(() => {
      debounceTimer.current = null
      pendingSince.current = null
      void save()
    }, delay)
  }, [ state.revision, save ])

  // アンマウント後にタイマーが走り続けると、離脱したページの状態を保存してしまう
  useEffect(() => {
    return () => {
      if (debounceTimer.current !== null) window.clearTimeout(debounceTimer.current)
      if (retryTimer.current !== null) window.clearTimeout(retryTimer.current)
    }
  }, [])

  // Turbo がリクエストを投げる直前に保存を済ませてから遷移させる。
  //
  // turbo:before-visit では間に合わない。Turboはフォーム送信のレスポンス（=新しい
  // ページのHTML）を受け取ってから visit を提案するため、サーバは古いDBの状態で
  // 画面を描画してしまう。before-fetch-request なら pause/resume でリクエスト自体を
  // 待たせられるので、リンク遷移・フォーム送信のどちらでも保存が先に完了する。
  useEffect(() => {
    const pauseAndSave = (event: Event): void => {
      if (latest.current.revision === savedRevision.current) return

      const detail = (event as CustomEvent<{ resume?: () => void }>).detail
      if (typeof detail?.resume !== "function") return

      event.preventDefault()
      void save().finally(() => detail.resume?.())
    }

    document.addEventListener("turbo:before-fetch-request", pauseAndSave)

    return () => document.removeEventListener("turbo:before-fetch-request", pauseAndSave)
  }, [ save ])

  // タブを閉じる・リロードする場合は応答を待てないため sendBeacon で投げ切る。
  // sendBeacon は必ずPOSTで送るので、ルーティング側でPOSTも受けている
  useEffect(() => {
    const flush = (): void => {
      if (latest.current.revision === savedRevision.current) return

      const sent = navigator.sendBeacon(saveUrl, new Blob([ buildBody() ], { type: "application/json" }))
      if (sent) savedRevision.current = latest.current.revision
    }

    window.addEventListener("pagehide", flush)

    return () => window.removeEventListener("pagehide", flush)
  }, [ buildBody, saveUrl ])

  return status
}
