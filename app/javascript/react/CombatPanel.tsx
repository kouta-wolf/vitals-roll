import { useReducer } from "react"
import { createPortal } from "react-dom"
import type { ReactNode } from "react"
import { combatStateReducer, initialCombatState } from "../domain/combatState"
import type { CombatStateData } from "../domain/combatState"
import { BuffList } from "./BuffList"
import { FormulaPanel } from "./FormulaPanel"
import { RoundControls } from "./RoundControls"
import { useCombatStateSave } from "./useCombatStateSave"

// 描画先はRails側のレイアウトに点在する（左カラムのラウンド管理とバフ一覧、右カラムの判定式）。
// 単一のreducerで扱うためルートは1つに保ち、各セクションへはPortalで差し込む。
// 描画先が無ければ何も描画しない（キャラクター詳細以外のページ）
function Portal({ targetId, children }: { targetId: string; children: ReactNode }) {
  const target = document.getElementById(targetId)
  if (target === null) return null

  return createPortal(children, target)
}

export function CombatPanel({ data }: { data: CombatStateData }) {
  const [ state, dispatch ] = useReducer(combatStateReducer, data, initialCombatState)
  const saveStatus = useCombatStateSave(data.saveUrl, data.csrfToken, state)

  const selectedWeapon = data.weapons.find((weapon) => weapon.id === state.selectedWeaponId) ?? null

  return (
    <>
      <Portal targetId="round-panel">
        <RoundControls currentRounds={state.currentRounds} saveStatus={saveStatus} dispatch={dispatch} />
      </Portal>

      <Portal targetId="buff-list-panel">
        <BuffList buffs={state.buffs} buffPathPrefix={data.buffPathPrefix} csrfToken={data.csrfToken} dispatch={dispatch} />
      </Portal>

      <Portal targetId="formula-panel">
        <FormulaPanel
          character={data.character}
          weapons={data.weapons}
          selectedWeapon={selectedWeapon}
          buffs={state.buffs}
          dispatch={dispatch}
        />
      </Portal>
    </>
  )
}
