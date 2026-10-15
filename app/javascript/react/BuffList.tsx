import type { Dispatch } from "react"
import { buffDisplayName } from "../domain/types"
import type { Buff } from "../domain/types"
import type { CombatAction } from "../domain/combatState"

interface Props {
  buffs: Buff[]
  // バフのCRUDはRails側のページ遷移のまま（#160のスコープ外）
  buffPathPrefix: string
  csrfToken: string
  dispatch: Dispatch<CombatAction>
}

export function BuffList({ buffs, buffPathPrefix, csrfToken, dispatch }: Props) {
  return (
    <div className="space-y-1 mt-3">
      {buffs.map((buff) => (
        <div key={buff.id}
          className={`flex items-center justify-between text-sm border-b border-gray-100 py-1 ${buff.active ? "" : "opacity-50"}`}>
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={buff.active}
              onChange={() => dispatch({ type: "toggleBuff", id: buff.id })}
              aria-label={`${buffDisplayName(buff)}の有効/無効`}
            />
            <span>{buffDisplayName(buff)}</span>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-gray-500">
              残り{buff.remainingRounds === null ? "∞" : `${buff.remainingRounds}R`}
            </span>
            <a href={`${buffPathPrefix}/${buff.id}/edit`} className="text-blue-600 hover:underline text-xs">編集</a>

            {/* Turboがフォーム送信を拾い、data-turbo-confirm で確認ダイアログを出す */}
            <form method="post" action={`${buffPathPrefix}/${buff.id}`} data-turbo-confirm="本当に削除しますか？">
              <input type="hidden" name="_method" value="delete" />
              <input type="hidden" name="authenticity_token" value={csrfToken} />
              <button type="submit" className="text-red-600 hover:underline text-xs bg-transparent p-0 border-0">削除</button>
            </form>
          </div>
        </div>
      ))}
    </div>
  )
}
