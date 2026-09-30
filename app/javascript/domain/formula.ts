import type { Buff, Character, TargetStatus, Weapon } from "./types"

// 正の値には + を付け、負の値はそのまま返す（"+-3" のような二重符号を避ける）
function signed(value: number): string {
  return value >= 0 ? `+${value}` : String(value)
}

function sumOf(values: readonly number[]): number {
  return values.reduce((total, value) => total + value, 0)
}

// 能力値をボーナス値へ換算する（÷6）。
//
// Ruby の Integer#/ は負数を切り捨てではなく切り下げる（-8 / 6 は -2）。
// JavaScript の Math.trunc は -1 を返すため、そのまま移植すると
// 能力値を下げるバフで結果がズレる。Rubyに揃えて Math.floor を使う。
function toAbilityBonus(abilityTotal: number): number {
  return Math.floor(abilityTotal / 6)
}

function activeBuffsFor(buffs: readonly Buff[], targetStatuses: readonly TargetStatus[]): Buff[] {
  return buffs.filter(
    (buff) => buff.active && buff.targetStatus !== null && targetStatuses.includes(buff.targetStatus)
  )
}

// 対象ステータスに対するactiveなバフの合計。
// ability は個別にではなく合計してから換算する点に注意。
// （+4 と +4 なら 0+0 ではなく 8/6 = 1 になる）
export function buffTotalFor(buffs: readonly Buff[], targetStatuses: readonly TargetStatus[]): number {
  const scope = activeBuffsFor(buffs, targetStatuses)

  const fixedTotal = sumOf(scope.filter((buff) => buff.valueKind === "fixed").map((buff) => buff.bonusValue))
  const abilityTotal = sumOf(scope.filter((buff) => buff.valueKind === "ability").map((buff) => buff.bonusValue))

  return fixedTotal + toAbilityBonus(abilityTotal)
}

// 同時に有効なのは常に1つという前提で、最初に見つかったものを使う
function findActiveSpecialBuff(buffs: readonly Buff[], specialType: string): Buff | undefined {
  return buffs.find((buff) => buff.active && buff.buffPreset?.specialType === specialType)
}

// special_type 由来の判定式末尾トークン。
// dice_fix は種別としては存在するが、Rails側の実装でも判定式には反映していないため
// ここでも扱わない（移植にあたって挙動を変えないため）。
function specialFormulaSuffix(buffs: readonly Buff[]): string {
  // クリティカルレイ: bonusValue をそのまま使う
  const criticalRay = findActiveSpecialBuff(buffs, "critical_ray")
  const criticalRaySuffix = criticalRay ? `$${signed(criticalRay.bonusValue)}` : ""

  // 首刈り刀: bonusValue は使わず固定で r5
  const kubikariSuffix = findActiveSpecialBuff(buffs, "kubikari") ? "r5" : ""

  return `${criticalRaySuffix}${kubikariSuffix}`
}

// 命中判定式: 2d6+<冒険者レベル + DEXボーナス + 命中補正>+<DEXバフ合計>
export function hitFormula(character: Character, weapon: Weapon, buffs: readonly Buff[]): string {
  const base = character.mainClassLevel + Math.floor(character.dexterity / 6) + weapon.fixedHitRate

  return `2d6${signed(base)}${signed(buffTotalFor(buffs, ["dexterity"]))}`
}

// ダメージ判定式: k<威力>[<クリティカル値>]+<固定値 + STR/damageバフ合計><特殊トークン>
// Rails側と同じく、キャラクターのステータスは参照しない。
export function attackFormula(weapon: Weapon, buffs: readonly Buff[]): string {
  const total = weapon.fixedValue + buffTotalFor(buffs, ["strength", "damage"])

  return `k${weapon.power}[${weapon.critical}]${signed(total)}${specialFormulaSuffix(buffs)}`
}
