import type { Buff, Character, Weapon } from "./types"

// キャラクター詳細ページの初期HTMLから受け取る、戦闘操作に必要なデータ一式
export interface CombatStateData {
  character: Character
  weapons: Weapon[]
  buffs: Buff[]
  // 保存先と、sendBeacon ではヘッダを付けられないためボディへ入れるCSRFトークン
  saveUrl: string
  csrfToken: string
  // バフのCRUDはRails側のページ遷移のまま。Reactからはリンク/フォームのURLとして使う
  buffPathPrefix: string
}

// Reactが管理する状態。selectedWeaponId はサーバへ保存しない表示上の選択
export interface CombatState {
  currentRounds: number
  buffs: Buff[]
  selectedWeaponId: number | null
  // 保存すべき変更が入るたびに増える。これを監視してデバウンス保存を起動する
  revision: number
}

export type CombatAction =
  | { type: "toggleBuff"; id: number }
  | { type: "advanceRound" }
  | { type: "retreatRound" }
  | { type: "resetRound" }
  | { type: "selectWeapon"; id: number }

export function initialCombatState(data: CombatStateData): CombatState {
  return {
    currentRounds: data.character.currentRounds,
    buffs: data.buffs,
    selectedWeaponId: data.weapons[0]?.id ?? null,
    revision: 0
  }
}

// 持続切れ(remainingRounds: 0)のバフをオンに戻すときは持続ラウンドを満タンへ回復する。
// #160 で Rails の Buff#toggle_active! から移植し、Ruby側は削除した
function toggleBuff(buff: Buff): Buff {
  if (!buff.active && buff.remainingRounds === 0 && buff.durationRounds !== null) {
    return { ...buff, active: true, remainingRounds: buff.durationRounds }
  }

  return { ...buff, active: !buff.active }
}

// 残ラウンドが0になったバフはオフへ落ちる。
// remainingRounds が null のバフは無限持続として対象外
function decrementRemaining(buff: Buff): Buff {
  if (!buff.active || buff.remainingRounds === null) return buff

  const remainingRounds = Math.max(buff.remainingRounds - 1, 0)

  return { ...buff, remainingRounds, active: remainingRounds > 0 }
}

// 持続ラウンドを超えて増えない。
// active は変化させない（切れてオフになったバフは対象外なので戻ってこない）
function incrementRemaining(buff: Buff): Buff {
  if (!buff.active || buff.remainingRounds === null) return buff

  const raised = buff.remainingRounds + 1
  const remainingRounds = buff.durationRounds === null ? raised : Math.min(raised, buff.durationRounds)

  return { ...buff, remainingRounds }
}

// 持続ラウンドを持つバフだけを初期値へ戻す。active の現在値に関係なくオフにする
function resetBuff(buff: Buff): Buff {
  if (buff.durationRounds === null) return buff

  return { ...buff, active: false, remainingRounds: buff.durationRounds }
}

export function combatStateReducer(state: CombatState, action: CombatAction): CombatState {
  switch (action.type) {
    case "toggleBuff":
      return {
        ...state,
        buffs: state.buffs.map((buff) => (buff.id === action.id ? toggleBuff(buff) : buff)),
        revision: state.revision + 1
      }

    case "advanceRound":
      return {
        ...state,
        currentRounds: state.currentRounds + 1,
        buffs: state.buffs.map(decrementRemaining),
        revision: state.revision + 1
      }

    case "retreatRound":
      // 0以下では何もしない
      if (state.currentRounds <= 0) return state

      return {
        ...state,
        currentRounds: state.currentRounds - 1,
        buffs: state.buffs.map(incrementRemaining),
        revision: state.revision + 1
      }

    case "resetRound":
      return {
        ...state,
        currentRounds: 0,
        buffs: state.buffs.map(resetBuff),
        revision: state.revision + 1
      }

    // 武器の選択はサーバへ保存しないため revision を進めない
    case "selectWeapon":
      return { ...state, selectedWeaponId: action.id }
  }
}

// 保存エンドポイントへ送るスナップショット。
// remainingRounds は無限持続の null も明示的に送る（キーを落とすと更新されない）
export function toSnapshot(state: CombatState) {
  return {
    current_rounds: state.currentRounds,
    buffs: state.buffs.map((buff) => ({
      id: buff.id,
      active: buff.active,
      remaining_rounds: buff.remainingRounds
    }))
  }
}
