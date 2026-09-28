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

// mainClassLevel / defense / currentRounds は現状DB側に NOT NULL 制約が無く、
// Rails側のバリデーションも掛かっていないため NULL を保存できてしまう（#168）。
// ここでは「シリアライザが必ず整数を渡す」ことを型の約束として non-nullable にしている。
// 約束が破れると判定式が NaN を含んだまま静かに壊れるため、#168 をDB/モデル側で
// 先に解消しておくこと。
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

// Ruby の String#presence 相当。空文字と空白のみの文字列は「無い」とみなす
function presence(value: string | null): string | null {
  return value !== null && value.trim() !== "" ? value : null
}

// Rails側の Buff#display_name（name.presence || buff_preset&.name）と揃える。
// ?? だけだと name が空文字のときにプリセット名へ落ちず、Railsと表示が食い違う。
//
// 戻り値だけは意図的に揃えていない。Railsは両方無いとき nil を返すが、
// ERBでは nil も空文字として描画されるため表示は同じで、TS側は string で
// 扱えたほうが呼び出し側が楽なため "" を返す。なお name もプリセットも無い
// 状態は Buff の presence バリデーションにより保存できない。
export function buffDisplayName(buff: Buff): string {
  return presence(buff.name) ?? buff.buffPreset?.name ?? ""
}
