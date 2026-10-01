import { act, cleanup, renderHook } from "@testing-library/react"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { DEBOUNCE_MS, MAX_WAIT_MS, RETRY_MS, useCombatStateSave } from "./useCombatStateSave"
import type { CombatState } from "../domain/combatState"

const SAVE_URL = "/characters/1/combat_state"
const TOKEN = "csrf-token"

function buildState(revision: number, currentRounds = 1): CombatState {
  return {
    currentRounds,
    buffs: [ { id: 1, name: "b", active: true, targetStatus: "strength", bonusValue: 1,
               valueKind: "fixed", durationRounds: 3, remainingRounds: 3, buffPreset: null } ],
    selectedWeaponId: null,
    revision
  }
}

let fetchMock: ReturnType<typeof vi.fn>
let beaconMock: ReturnType<typeof vi.fn>

beforeEach(() => {
  vi.useFakeTimers()
  fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 204 })
  beaconMock = vi.fn().mockReturnValue(true)
  vi.stubGlobal("fetch", fetchMock)
  vi.stubGlobal("navigator", { ...navigator, sendBeacon: beaconMock })
})

afterEach(() => {
  // Vitestは globals: false なので testing-library の自動クリーンアップが働かない。
  // 明示的に unmount しないと前のテストのイベントリスナが残り続ける
  cleanup()
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

function renderSave(initial: CombatState) {
  return renderHook(({ state }: { state: CombatState }) => useCombatStateSave(SAVE_URL, TOKEN, state), {
    initialProps: { state: initial }
  })
}

describe("useCombatStateSave", () => {
  it("変更が無ければ保存しない", async () => {
    renderSave(buildState(0))
    await act(async () => { vi.advanceTimersByTime(MAX_WAIT_MS * 2) })

    expect(fetchMock).not.toHaveBeenCalled()
  })

  it("変更直後は未保存、デバウンス経過後に保存される", async () => {
    const { result, rerender } = renderSave(buildState(0))

    act(() => { rerender({ state: buildState(1, 2) }) })
    expect(result.current).toBe("unsaved")
    expect(fetchMock).not.toHaveBeenCalled()

    await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS) })

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(result.current).toBe("saved")
  })

  // 連打しても送信は1回にまとまる
  it("連続した変更は1回のリクエストにまとめられる", async () => {
    const { rerender } = renderSave(buildState(0))

    for (let i = 1; i <= 5; i++) {
      act(() => { rerender({ state: buildState(i, i + 1) }) })
      await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS / 2) })
    }
    await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS) })

    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  // 操作が続いていても未保存のまま放置しない
  it("操作が続いてもMAX_WAITで打ち切って保存する", async () => {
    const { rerender } = renderSave(buildState(0))
    let revision = 0

    // デバウンスが毎回リセットされ続ける間隔で操作を続ける
    for (let elapsed = 0; elapsed < MAX_WAIT_MS + DEBOUNCE_MS; elapsed += DEBOUNCE_MS / 2) {
      revision += 1
      act(() => { rerender({ state: buildState(revision, revision) }) })
      await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS / 2) })
    }

    expect(fetchMock).toHaveBeenCalled()
  })

  it("送信ボディにスナップショットとCSRFトークンを含める", async () => {
    const { rerender } = renderSave(buildState(0))

    act(() => { rerender({ state: buildState(1, 4) }) })
    await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS) })

    const [ , init ] = fetchMock.mock.calls[0] ?? []
    const body = JSON.parse((init as RequestInit).body as string)
    expect(body).toEqual({
      current_rounds: 4,
      buffs: [ { id: 1, active: true, remaining_rounds: 3 } ],
      authenticity_token: TOKEN
    })
  })

  describe("失敗時", () => {
    it("422では未保存になり、再試行しない", async () => {
      fetchMock.mockResolvedValue({ ok: false, status: 422 })
      const { result, rerender } = renderSave(buildState(0))

      act(() => { rerender({ state: buildState(1, 2) }) })
      await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS) })
      expect(result.current).toBe("unsaved")

      await act(async () => { vi.advanceTimersByTime(RETRY_MS * 3) })
      expect(fetchMock).toHaveBeenCalledTimes(1)
    })

    it("500では再試行する", async () => {
      fetchMock.mockResolvedValue({ ok: false, status: 500 })
      const { rerender } = renderSave(buildState(0))

      act(() => { rerender({ state: buildState(1, 2) }) })
      await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS) })
      expect(fetchMock).toHaveBeenCalledTimes(1)

      await act(async () => { vi.advanceTimersByTime(RETRY_MS) })
      expect(fetchMock).toHaveBeenCalledTimes(2)
    })

    it("回線断でも再試行する", async () => {
      fetchMock.mockRejectedValue(new Error("offline"))
      const { result, rerender } = renderSave(buildState(0))

      act(() => { rerender({ state: buildState(1, 2) }) })
      await act(async () => { vi.advanceTimersByTime(DEBOUNCE_MS) })
      expect(result.current).toBe("unsaved")

      await act(async () => { vi.advanceTimersByTime(RETRY_MS) })
      expect(fetchMock).toHaveBeenCalledTimes(2)
    })
  })

  describe("ページ離脱時のフラッシュ", () => {
    it("pagehideでsendBeaconを使って送る", async () => {
      const { rerender } = renderSave(buildState(0))
      act(() => { rerender({ state: buildState(1, 3) }) })

      act(() => { window.dispatchEvent(new Event("pagehide")) })

      expect(beaconMock).toHaveBeenCalledTimes(1)
      const [ , blob ] = beaconMock.mock.calls[0] ?? []
      expect((blob as Blob).type).toBe("application/json")
    })

    // Turbo Drive の遷移では pagehide が発火しない
    it("turbo:before-visitでも送る", async () => {
      const { rerender } = renderSave(buildState(0))
      act(() => { rerender({ state: buildState(1, 3) }) })

      act(() => { document.dispatchEvent(new Event("turbo:before-visit")) })

      expect(beaconMock).toHaveBeenCalledTimes(1)
    })

    it("未保存の変更が無ければ送らない", () => {
      renderSave(buildState(0))
      act(() => { window.dispatchEvent(new Event("pagehide")) })

      expect(beaconMock).not.toHaveBeenCalled()
    })
  })
})
