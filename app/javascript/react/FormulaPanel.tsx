import type { Dispatch } from "react"
import { attackFormula, hitFormula } from "../domain/formula"
import type { Buff, Character, Weapon } from "../domain/types"
import type { CombatAction } from "../domain/combatState"
import { CopyButton } from "./CopyButton"

interface Props {
  character: Character
  weapons: Weapon[]
  selectedWeapon: Weapon | null
  buffs: Buff[]
  dispatch: Dispatch<CombatAction>
}

export function FormulaPanel({ character, weapons, selectedWeapon, buffs, dispatch }: Props) {
  if (selectedWeapon === null) {
    return <p className="text-gray-500 mt-2">武器が登録されていません。判定式を表示するには武器を登録してください。</p>
  }

  // 表示とコピーで同じ文字列を使う（二度評価すると乖離し得る）
  const hit = hitFormula(character, selectedWeapon, buffs)
  const attack = attackFormula(selectedWeapon, buffs)

  return (
    <div className="mt-2">
      <label className="block text-sm font-medium mb-1">武器選択</label>
      <div className="flex gap-2">
        {weapons.map((weapon) => (
          <button
            key={weapon.id}
            type="button"
            onClick={() => dispatch({ type: "selectWeapon", id: weapon.id })}
            className={`px-3 py-1 rounded border text-sm ${
              weapon.id === selectedWeapon.id
                ? "bg-blue-600 text-white border-blue-600"
                : "bg-white text-gray-700 border-gray-300"
            }`}
          >
            {weapon.name}
          </button>
        ))}
      </div>

      <p className="mt-2 flex items-center gap-2">
        命中判定式:
        <span>{hit}</span>
        <CopyButton text={hit} />
      </p>
      <p className="mt-2 flex items-center gap-2">
        ダメージ判定式:
        <span>{attack}</span>
        <CopyButton text={attack} />
      </p>
    </div>
  )
}
