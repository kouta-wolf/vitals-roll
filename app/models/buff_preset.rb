class BuffPreset < ApplicationRecord
  # 判定式末尾へポン付けする特殊トークンの種別。nil = 通常バフ。
  # DBには文字列で保存する(integer enumだと後から並べ替えるとズレる/管理人がDBを直接見て意味が分かる方が運用に向くため)
  enum :special_type, {
    critical_ray: "critical_ray", # クリティカルレイ: 判定式末尾に $+x (x = bonus_value)
    kubikari:     "kubikari",     # 首刈り刀: 判定式末尾に r5 (現状は固定値。bonus_valueは未使用)
    dice_fix:     "dice_fix"      # ダイス目固定(変転時など): 判定式末尾に $x (x = bonus_value)
  }

  # 補正対象ステータス。通常バフはこのいずれかに bonus_value を加算する
  TARGET_STATUSES = %w[
    dexterity agility strength vitality intelligence spirit
    magic_power life_resistance spirit_resistance
  ].freeze

  validates :name, presence: true, uniqueness: true
  # bonus_value: 通常バフ=ステータス補正値 / 特殊バフ=トークンのx(kubikariは未使用)
  validates :bonus_value, numericality: { only_integer: true, in: -999..999 }
  validates :duration_rounds, numericality: { only_integer: true, in: 0..50 }, allow_nil: true
  validates :target_status, inclusion: { in: TARGET_STATUSES }, allow_nil: true
  # 通常バフ(special_type=nil)のみ対象ステータス必須。特殊バフは末尾ポン付けのため不要
  validates :target_status, presence: true, if: -> { special_type.nil? }
end
