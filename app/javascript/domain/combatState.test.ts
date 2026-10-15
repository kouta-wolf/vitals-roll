import { describe, expect, it } from "vitest"
import { combatStateReducer, initialCombatState, toSnapshot } from "./combatState"
import type { CombatState, CombatStateData } from "./combatState"
import type { Buff, Character, Weapon } from "./types"

function buildBuff(overrides: Partial<Buff> = {}): Buff {
  return {
    id: 1,
    name: "テストバフ",
    active: false,
    targetStatus: "strength",
    bonusValue: 1,
    valueKind: "fixed",
    durationRounds: 3,
    remainingRounds: 3,
    buffPreset: null,
    ...overrides
  }
}

function buildState(overrides: Partial<CombatState> = {}): CombatState {
  return { currentRounds: 1, buffs: [], selectedWeaponId: null, revision: 0, ...overrides }
}

const character: Character = {
  id: 1, name: "テスター", race: null, mainClass: null, mainClassLevel: 3,
  dexterity: 12, agility: 12, strength: 12, vitality: 12, intelligence: 12, spirit: 12,
  defense: 4, currentRounds: 2
}

const weapon: Weapon = { id: 7, name: "剣", power: 25, critical: 10, fixedValue: 1, fixedHitRate: 0 }

describe("initialCombatState", () => {
  const data: CombatStateData = {
    character, weapons: [ weapon ], buffs: [ buildBuff() ],
    saveUrl: "/x", csrfToken: "t", buffPathPrefix: "/characters/1/buffs"
  }

  it("キャラクターの現在ラウンドを引き継ぐ", () => {
    expect(initialCombatState(data).currentRounds).toBe(2)
  })

  it("先頭の武器を選択状態にする", () => {
    expect(initialCombatState(data).selectedWeaponId).toBe(7)
  })

  it("武器が無ければ選択なしになる", () => {
    expect(initialCombatState({ ...data, weapons: [] }).selectedWeaponId).toBeNull()
  })
})

// #160 で Rails から移植したラウンド/トグルのルール。移植時に Ruby の実挙動と突き合わせ済み
describe("toggleBuff", () => {
  it("activeなバフはfalseに反転する", () => {
    const state = buildState({ buffs: [ buildBuff({ active: true, remainingRounds: 2 }) ] })
    const next = combatStateReducer(state, { type: "toggleBuff", id: 1 })

    expect(next.buffs[0]).toMatchObject({ active: false, remainingRounds: 2 })
  })

  it("持続切れでないバフは残ラウンドを変えずにtrueへ戻る", () => {
    const state = buildState({ buffs: [ buildBuff({ active: false, remainingRounds: 2 }) ] })
    const next = combatStateReducer(state, { type: "toggleBuff", id: 1 })

    expect(next.buffs[0]).toMatchObject({ active: true, remainingRounds: 2 })
  })

  it("持続切れ(0)のバフは残ラウンドを持続ラウンドまで戻してtrueになる", () => {
    const state = buildState({ buffs: [ buildBuff({ active: false, remainingRounds: 0, durationRounds: 3 }) ] })
    const next = combatStateReducer(state, { type: "toggleBuff", id: 1 })

    expect(next.buffs[0]).toMatchObject({ active: true, remainingRounds: 3 })
  })

  it("無限持続(null)のバフは残ラウンドを変えずにtrueへ戻る", () => {
    const state = buildState({ buffs: [ buildBuff({ active: false, remainingRounds: null, durationRounds: null }) ] })
    const next = combatStateReducer(state, { type: "toggleBuff", id: 1 })

    expect(next.buffs[0]).toMatchObject({ active: true, remainingRounds: null })
  })

  it("対象外のバフは変化しない", () => {
    const state = buildState({ buffs: [ buildBuff({ id: 1, active: false }), buildBuff({ id: 2, active: false }) ] })
    const next = combatStateReducer(state, { type: "toggleBuff", id: 1 })

    expect(next.buffs[1]?.active).toBe(false)
  })
})

// ラウンドを進める
describe("advanceRound", () => {
  it("現在ラウンドが1増える", () => {
    expect(combatStateReducer(buildState(), { type: "advanceRound" }).currentRounds).toBe(2)
  })

  it("activeなバフの残ラウンドが1減る", () => {
    const state = buildState({ buffs: [ buildBuff({ active: true, remainingRounds: 3 }) ] })
    expect(combatStateReducer(state, { type: "advanceRound" }).buffs[0]).toMatchObject({ remainingRounds: 2, active: true })
  })

  it("残ラウンドが1のバフは0になりオフへ落ちる", () => {
    const state = buildState({ buffs: [ buildBuff({ active: true, remainingRounds: 1 }) ] })
    expect(combatStateReducer(state, { type: "advanceRound" }).buffs[0]).toMatchObject({ remainingRounds: 0, active: false })
  })

  it("無限持続のバフは変化しない", () => {
    const state = buildState({ buffs: [ buildBuff({ active: true, remainingRounds: null, durationRounds: null }) ] })
    expect(combatStateReducer(state, { type: "advanceRound" }).buffs[0]).toMatchObject({ remainingRounds: null, active: true })
  })

  it("オフのバフは対象外で変化しない", () => {
    const state = buildState({ buffs: [ buildBuff({ active: false, remainingRounds: 3 }) ] })
    expect(combatStateReducer(state, { type: "advanceRound" }).buffs[0]).toMatchObject({ remainingRounds: 3, active: false })
  })
})

// ラウンドを戻す
describe("retreatRound", () => {
  it("現在ラウンドが1減る", () => {
    expect(combatStateReducer(buildState({ currentRounds: 3 }), { type: "retreatRound" }).currentRounds).toBe(2)
  })

  it("現在ラウンドが0なら何も変わらない", () => {
    const state = buildState({ currentRounds: 0, buffs: [ buildBuff({ active: true, remainingRounds: 1 }) ] })
    const next = combatStateReducer(state, { type: "retreatRound" })

    expect(next).toBe(state)
  })

  it("activeなバフの残ラウンドが1増える", () => {
    const state = buildState({ currentRounds: 3, buffs: [ buildBuff({ active: true, remainingRounds: 1 }) ] })
    expect(combatStateReducer(state, { type: "retreatRound" }).buffs[0]).toMatchObject({ remainingRounds: 2 })
  })

  it("持続ラウンドに達していればそれ以上増えない", () => {
    const state = buildState({ currentRounds: 3, buffs: [ buildBuff({ active: true, remainingRounds: 3, durationRounds: 3 }) ] })
    expect(combatStateReducer(state, { type: "retreatRound" }).buffs[0]).toMatchObject({ remainingRounds: 3 })
  })

  it("無限持続のバフは変化しない", () => {
    const state = buildState({ currentRounds: 3, buffs: [ buildBuff({ active: true, remainingRounds: null, durationRounds: null }) ] })
    expect(combatStateReducer(state, { type: "retreatRound" }).buffs[0]).toMatchObject({ remainingRounds: null })
  })

  // 切れてオフになったバフが戻ってこないことを保証する
  it("オフのバフは対象外で変化しない", () => {
    const state = buildState({ currentRounds: 3, buffs: [ buildBuff({ active: false, remainingRounds: 0 }) ] })
    expect(combatStateReducer(state, { type: "retreatRound" }).buffs[0]).toMatchObject({ remainingRounds: 0, active: false })
  })
})

// ラウンドをリセットする
describe("resetRound", () => {
  it("現在ラウンドが0に戻る", () => {
    expect(combatStateReducer(buildState({ currentRounds: 9 }), { type: "resetRound" }).currentRounds).toBe(0)
  })

  it("持続バフは残ラウンドが持続ラウンドへ戻りオフになる", () => {
    const state = buildState({ buffs: [ buildBuff({ active: true, remainingRounds: 1, durationRounds: 3 }) ] })
    expect(combatStateReducer(state, { type: "resetRound" }).buffs[0]).toMatchObject({ active: false, remainingRounds: 3 })
  })

  it("無限持続のバフは変化しない", () => {
    const state = buildState({ buffs: [ buildBuff({ active: true, remainingRounds: null, durationRounds: null }) ] })
    expect(combatStateReducer(state, { type: "resetRound" }).buffs[0]).toMatchObject({ active: true, remainingRounds: null })
  })
})

describe("selectWeapon", () => {
  it("選択中の武器を変える", () => {
    expect(combatStateReducer(buildState(), { type: "selectWeapon", id: 42 }).selectedWeaponId).toBe(42)
  })

  // 武器の選択はサーバへ保存しないため保存を起動してはいけない
  it("revisionを進めない", () => {
    expect(combatStateReducer(buildState(), { type: "selectWeapon", id: 42 }).revision).toBe(0)
  })
})

describe("revision", () => {
  it("状態を変える操作では増える", () => {
    const actions = [ { type: "advanceRound" }, { type: "retreatRound" }, { type: "resetRound" } ] as const

    actions.forEach((action) => {
      expect(combatStateReducer(buildState({ currentRounds: 5 }), action).revision).toBe(1)
    })
  })

  it("変化しなかった retreatRound では増えない", () => {
    expect(combatStateReducer(buildState({ currentRounds: 0 }), { type: "retreatRound" }).revision).toBe(0)
  })
})

describe("toSnapshot", () => {
  it("保存エンドポイントのキー名へ変換する", () => {
    const state = buildState({
      currentRounds: 4,
      buffs: [ buildBuff({ id: 10, active: true, remainingRounds: 2 }) ]
    })

    expect(toSnapshot(state)).toEqual({
      current_rounds: 4,
      buffs: [ { id: 10, active: true, remaining_rounds: 2 } ]
    })
  })

  // キーを落とすとサーバ側で更新されないため、無限持続も null を明示して送る
  it("無限持続のバフも remaining_rounds を null として含める", () => {
    const state = buildState({ buffs: [ buildBuff({ id: 11, remainingRounds: null, durationRounds: null }) ] })

    expect(toSnapshot(state).buffs[0]).toEqual({ id: 11, active: false, remaining_rounds: null })
  })
})
