import { describe, expect, it } from "vitest"
import { buffDisplayName } from "./types"
import type { Buff, BuffPreset } from "./types"

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

const preset: BuffPreset = { id: 1, name: "マッスルベアー", specialType: null }

describe("buffDisplayName", () => {
  it("カスタムバフは自身のnameを返す", () => {
    expect(buffDisplayName(buildBuff({ name: "自作バフ" }))).toBe("自作バフ")
  })

  it("プリセット由来(name: null)はプリセット名を返す", () => {
    expect(buffDisplayName(buildBuff({ name: null, buffPreset: preset }))).toBe("マッスルベアー")
  })

  // Rails の name.presence || buff_preset&.name と揃える。
  // ?? で書くと空文字が採用されてしまい、Railsの表示と食い違う
  it("nameが空文字ならプリセット名へ落ちる", () => {
    expect(buffDisplayName(buildBuff({ name: "", buffPreset: preset }))).toBe("マッスルベアー")
  })

  it("nameが空白のみでもプリセット名へ落ちる", () => {
    expect(buffDisplayName(buildBuff({ name: "   ", buffPreset: preset }))).toBe("マッスルベアー")
  })

  // Railsはこの場合 nil を返すが、ERBでは nil も空文字として描画されるため表示は同じ。
  // そもそも presence バリデーションにより、この状態のバフは保存できない
  it("nameもプリセットも無ければ空文字を返す", () => {
    expect(buffDisplayName(buildBuff({ name: null, buffPreset: null }))).toBe("")
  })
})
