// SW2.5のキャラクターシートをフロントエンドで扱うための型。
// Rails側のモデル（Character / Weapon / Buff / BuffPreset）と対応する。

export const TARGET_STATUSES = [
  "dexterity",
  "agility",
  "strength",
  "vitality",
  "intelligence",
  "spirit",
  "magic_power",
  "life_resistance",
  "spirit_resistance",
  // damage: 筋力等を介さず判定式のダメージ部分へ直接増減するバフ
  "damage"
] as const

export type TargetStatus = (typeof TARGET_STATUSES)[number]

// 判定式の末尾へポン付けする特殊トークンの種別。null は通常バフ。
export const SPECIAL_TYPES = ["critical_ray", "kubikari", "dice_fix"] as const

export type SpecialType = (typeof SPECIAL_TYPES)[number]

// fixed: 判定式へそのまま加算する固定値/ボーナス値
// ability: 能力値そのものの増減。ボーナス換算(÷6)を経てから加算する
export type ValueKind = "fixed" | "ability"

export interface BuffPreset {
  id: number
  name: string
  specialType: SpecialType | null
}

export interface Buff {
  id: number
  // プリセット由来のバフは名前を持たず、buffPreset.name を参照する
  name: string | null
  active: boolean
  // 特殊バフ(specialType あり)は対象ステータスの概念を持たないため null
  targetStatus: TargetStatus | null
  bonusValue: number
  valueKind: ValueKind
  // null は無限持続
  durationRounds: number | null
  remainingRounds: number | null
  buffPreset: BuffPreset | null
}

export interface Weapon {
  id: number
  name: string
  power: number
  critical: number
  fixedValue: number
  fixedHitRate: number
}

export interface Character {
  id: number
  name: string
  race: string | null
  mainClass: string | null
  mainClassLevel: number
  dexterity: number
  agility: number
  strength: number
  vitality: number
  intelligence: number
  spirit: number
  defense: number
  currentRounds: number
}

export function buffDisplayName(buff: Buff): string {
  return buff.name ?? buff.buffPreset?.name ?? ""
}
