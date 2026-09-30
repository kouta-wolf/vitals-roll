import { describe, expect, it } from "vitest"
import { attackFormula, buffTotalFor, hitFormula } from "./formula"
import type { Buff, BuffPreset, Character, Weapon } from "./types"

// spec/factories の character / weapon と同じ既定値に揃えてある
function buildCharacter(overrides: Partial<Character> = {}): Character {
  return {
    id: 1,
    name: "テスター・ドラゴン",
    race: "テストドレイク",
    mainClass: "ファイター",
    mainClassLevel: 3,
    dexterity: 12,
    agility: 12,
    strength: 12,
    vitality: 12,
    intelligence: 12,
    spirit: 12,
    defense: 4,
    currentRounds: 1,
    ...overrides
  }
}

function buildWeapon(overrides: Partial<Weapon> = {}): Weapon {
  return {
    id: 1,
    name: "テストソード",
    power: 25,
    critical: 10,
    fixedValue: 1,
    fixedHitRate: 0,
    ...overrides
  }
}

let nextBuffId = 1

function buildBuff(overrides: Partial<Buff> = {}): Buff {
  return {
    id: nextBuffId++,
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

function buildPreset(overrides: Partial<BuffPreset> = {}): BuffPreset {
  return { id: 1, name: "テストプリセット", specialType: null, ...overrides }
}

describe("hitFormula", () => {
  const character = buildCharacter({ mainClassLevel: 3, dexterity: 12 })
  const weapon = buildWeapon({ fixedHitRate: 0 })

  it("バフなしの場合、クラスLv+器用度ボーナスのみの式になる", () => {
    expect(hitFormula(character, weapon, [])).toBe("2d6+5+0")
  })

  it("武器の命中補正が式に反映される", () => {
    expect(hitFormula(character, buildWeapon({ fixedHitRate: 2 }), [])).toBe("2d6+7+0")
  })

  it("対象ステータス(dexterity)のactiveなバフ合計が式に反映される", () => {
    const buffs = [
      buildBuff({ active: true, targetStatus: "dexterity", bonusValue: 1 }),
      buildBuff({ active: true, targetStatus: "dexterity", bonusValue: 2 })
    ]
    expect(hitFormula(character, weapon, buffs)).toBe("2d6+5+3")
  })

  it("activeがfalseのバフは合算されない", () => {
    const buffs = [buildBuff({ active: false, targetStatus: "dexterity", bonusValue: 5 })]
    expect(hitFormula(character, weapon, buffs)).toBe("2d6+5+0")
  })

  it("対象ステータスが異なるバフ(strength等)は合算されない", () => {
    const buffs = [buildBuff({ active: true, targetStatus: "strength", bonusValue: 5 })]
    expect(hitFormula(character, weapon, buffs)).toBe("2d6+5+0")
  })

  it("バフ合計が負の値でも式に空白や二重符号が入らない", () => {
    const buffs = [buildBuff({ active: true, targetStatus: "dexterity", bonusValue: -3 })]
    expect(hitFormula(character, weapon, buffs)).toBe("2d6+5-3")
    expect(hitFormula(character, weapon, buffs)).not.toContain(" ")
  })

  it("複数武器があっても武器ごとに正しい式を返す", () => {
    expect(hitFormula(character, weapon, [])).toBe("2d6+5+0")
    expect(hitFormula(character, buildWeapon({ fixedHitRate: -1 }), [])).toBe("2d6+4+0")
  })

  it("能力値上昇バフ(ability)はボーナス換算(÷6)されて加算される", () => {
    // 器用度値+12 → ボーナス+2
    const buffs = [buildBuff({ active: true, targetStatus: "dexterity", valueKind: "ability", bonusValue: 12 })]
    expect(hitFormula(character, weapon, buffs)).toBe("2d6+5+2")
  })
})

describe("attackFormula", () => {
  const weapon = buildWeapon({ power: 25, critical: 10, fixedValue: 1 })

  it("バフなしの場合、武器の威力・クリティカル値・固定値のみの式になる", () => {
    expect(attackFormula(weapon, [])).toBe("k25[10]+1")
  })

  it("対象ステータス(strength)のactiveなバフ合計が式に反映される", () => {
    const buffs = [buildBuff({ active: true, targetStatus: "strength", bonusValue: 3 })]
    expect(attackFormula(weapon, buffs)).toBe("k25[10]+4")
  })

  it("対象ステータス(damage)のactiveなバフ合計も式に反映される", () => {
    const buffs = [
      buildBuff({ active: true, targetStatus: "strength", bonusValue: 3 }),
      buildBuff({ active: true, targetStatus: "damage", bonusValue: 2 })
    ]
    expect(attackFormula(weapon, buffs)).toBe("k25[10]+6")
  })

  it("activeがfalseのバフは合算されない", () => {
    const buffs = [buildBuff({ active: false, targetStatus: "damage", bonusValue: 5 })]
    expect(attackFormula(weapon, buffs)).toBe("k25[10]+1")
  })

  it("対象ステータスが異なるバフ(dexterity等)は合算されない", () => {
    const buffs = [buildBuff({ active: true, targetStatus: "dexterity", bonusValue: 5 })]
    expect(attackFormula(weapon, buffs)).toBe("k25[10]+1")
  })

  it("バフ合計を含めた結果が負の値でも式に空白や二重符号が入らない", () => {
    const buffs = [buildBuff({ active: true, targetStatus: "damage", bonusValue: -5 })]
    expect(attackFormula(weapon, buffs)).toBe("k25[10]-4")
    expect(attackFormula(weapon, buffs)).not.toContain(" ")
  })

  it("複数武器があっても武器ごとに正しい式を返す", () => {
    const buffs = [buildBuff({ active: true, targetStatus: "strength", bonusValue: 2 })]
    expect(attackFormula(weapon, buffs)).toBe("k25[10]+3")
    expect(attackFormula(buildWeapon({ power: 40, critical: 9, fixedValue: 3 }), buffs)).toBe("k40[9]+5")
  })

  describe("valueKind: ability(能力値そのものを上げるバフ)", () => {
    it("能力値上昇バフはボーナス換算(÷6)されて加算される", () => {
      // 筋力値+12 → ボーナス+2
      const buffs = [buildBuff({ active: true, targetStatus: "strength", valueKind: "ability", bonusValue: 12 })]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+3")
    })

    it("6の倍数でない能力値上昇バフは端数が切り捨てられる", () => {
      // 筋力値+8 → 8/6=1 → ボーナス+1
      const buffs = [buildBuff({ active: true, targetStatus: "strength", valueKind: "ability", bonusValue: 8 })]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+2")
    })

    it("ability(換算あり)とfixed(換算なし)のバフが正しく区別して合算される", () => {
      const buffs = [
        buildBuff({ active: true, targetStatus: "strength", valueKind: "ability", bonusValue: 12 }), // → +2
        buildBuff({ active: true, targetStatus: "damage", valueKind: "fixed", bonusValue: 3 }) // → +3
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+6")
    })

    it("能力値低下バフ(負値)もボーナス換算され二重符号にならない", () => {
      // 筋力値-12 → ボーナス-2 → 1-2=-1
      const buffs = [buildBuff({ active: true, targetStatus: "strength", valueKind: "ability", bonusValue: -12 })]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]-1")
      expect(attackFormula(weapon, buffs)).not.toContain(" ")
    })

    // Ruby の Integer#/ は切り下げなので -8 / 6 は -2。
    // Math.trunc で移植すると -1 になり挙動が変わるため、ここで固定する。
    it("6の倍数でない能力値低下バフは Ruby と同じく切り下げられる", () => {
      const buffs = [buildBuff({ active: true, targetStatus: "strength", valueKind: "ability", bonusValue: -8 })]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]-1")
    })

    it("能力値-1でもボーナスは-1になる(切り下げ)", () => {
      const buffs = [buildBuff({ active: true, targetStatus: "strength", valueKind: "ability", bonusValue: -1 })]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+0")
    })

    // 個別に換算すると 0+0 になってしまう。合計してから換算する必要がある
    it("複数のabilityバフは合計してから換算される", () => {
      const buffs = [
        buildBuff({ active: true, targetStatus: "strength", valueKind: "ability", bonusValue: 4 }),
        buildBuff({ active: true, targetStatus: "damage", valueKind: "ability", bonusValue: 4 })
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+2")
    })
  })

  describe("specialType(critical_ray / kubikari)による特殊接尾辞", () => {
    const criticalRayPreset = buildPreset({ id: 10, name: "クリティカルレイ", specialType: "critical_ray" })
    const kubikariPreset = buildPreset({ id: 11, name: "首刈り刀", specialType: "kubikari" })

    it("critical_rayのactiveなバフがあれば末尾に$+xが付与される", () => {
      const buffs = [
        buildBuff({ active: true, name: null, targetStatus: null, bonusValue: 1, buffPreset: criticalRayPreset })
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+1$+1")
    })

    it("critical_rayがactive: falseなら付与されない", () => {
      const buffs = [
        buildBuff({ active: false, name: null, targetStatus: null, bonusValue: 1, buffPreset: criticalRayPreset })
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+1")
    })

    it("kubikariのactiveなバフがあれば末尾にr5が付与される", () => {
      const buffs = [
        buildBuff({ active: true, name: null, targetStatus: null, bonusValue: 0, buffPreset: kubikariPreset })
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+1r5")
    })

    it("kubikariがactive: falseなら付与されない", () => {
      const buffs = [
        buildBuff({ active: false, name: null, targetStatus: null, bonusValue: 0, buffPreset: kubikariPreset })
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+1")
    })

    it("critical_rayとkubikariが両方activeな場合、$+xの後にr5が続く", () => {
      const buffs = [
        buildBuff({ active: true, name: null, targetStatus: null, bonusValue: 2, buffPreset: criticalRayPreset }),
        buildBuff({ active: true, name: null, targetStatus: null, bonusValue: 0, buffPreset: kubikariPreset })
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+1$+2r5")
    })

    // 特殊バフは targetStatus を持たないため、通常のバフ合計には含めない
    it("特殊バフのbonusValueはダメージ部分へ加算されない", () => {
      const buffs = [
        buildBuff({ active: true, name: null, targetStatus: null, bonusValue: 9, buffPreset: criticalRayPreset })
      ]
      expect(attackFormula(weapon, buffs)).toBe("k25[10]+1$+9")
    })
  })
})

describe("buffTotalFor", () => {
  it("対象ステータスを複数指定すると両方を合算する", () => {
    const buffs = [
      buildBuff({ active: true, targetStatus: "strength", bonusValue: 2 }),
      buildBuff({ active: true, targetStatus: "damage", bonusValue: 3 }),
      buildBuff({ active: true, targetStatus: "dexterity", bonusValue: 100 })
    ]
    expect(buffTotalFor(buffs, ["strength", "damage"])).toBe(5)
  })

  it("バフが空なら0を返す", () => {
    expect(buffTotalFor([], ["strength"])).toBe(0)
  })
})
