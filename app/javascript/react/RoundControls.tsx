import type { Dispatch } from "react"
import type { CombatAction } from "../domain/combatState"
import { SaveStatusBadge } from "./SaveStatusBadge"
import type { SaveStatus } from "./useCombatStateSave"

const BUTTON_BASE = "inline-flex h-8 items-center rounded-md px-3 text-sm transition active:scale-95 hover:cursor-pointer"

interface Props {
  currentRounds: number
  saveStatus: SaveStatus
  dispatch: Dispatch<CombatAction>
}

export function RoundControls({ currentRounds, saveStatus, dispatch }: Props) {
  const reset = (): void => {
    if (window.confirm("ラウンドをリセットしますか？（無限バフ以外の持続ラウンドも初期値に戻ります）")) {
      dispatch({ type: "resetRound" })
    }
  }

  return (
    <div className="flex items-center gap-4">
      <p className="text-lg">
        現在のラウンド: <span className="font-bold">{currentRounds}</span>
      </p>

      <button type="button" onClick={() => dispatch({ type: "retreatRound" })}
        className={`${BUTTON_BASE} bg-gray-200 hover:bg-gray-300`}>戻す</button>
      <button type="button" onClick={() => dispatch({ type: "advanceRound" })}
        className={`${BUTTON_BASE} bg-blue-600 hover:bg-blue-700 text-white`}>進める</button>
      <button type="button" onClick={reset}
        className={`${BUTTON_BASE} bg-red-600 hover:bg-red-700 text-white`}>リセット</button>

      <SaveStatusBadge status={saveStatus} />
    </div>
  )
}
