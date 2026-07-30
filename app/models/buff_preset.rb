class BuffPreset < ApplicationRecord
  has_many :buffs # 管理人所有のマスターデータのためdependent: :destroyは付けない

  # 判定式末尾へポン付けする特殊トークンの種別。nil = 通常バフ。
  # DBには文字列で保存する(integer enumだと後から並べ替えるとズレる/管理人がDBを直接見て意味が分かる方が運用に向くため)
  enum :special_type, {
    critical_ray: "critical_ray", # クリティカルレイ: 判定式末尾に $+x (x = bonus_value)
    kubikari:     "kubikari",     # 首刈り刀: 判定式末尾に r5 (現状は固定値。bonus_valueは未使用)
    dice_fix:     "dice_fix"      # ダイス目固定(変転時など): 判定式末尾に $x (x = bonus_value)
  }

  # bonus_valueの単位。special_typeと同様、DB直読みで意味が分かるようstringで保存する
  enum :value_kind, {
    fixed:   "fixed",  # 判定式へそのまま加算する固定値/ボーナス値
    ability: "ability" # 能力値そのものの増減。ボーナス換算(÷6切り捨て)を経てから加算する
  }, default: :fixed

  # 補正対象ステータス。通常バフはこのいずれかに bonus_value を加算する
  # damage: 筋力等を介さず判定式のダメージ部分へ直接増減するバフ（例: ダメージ+1/-1）用
  TARGET_STATUSES = %w[
    dexterity agility strength vitality intelligence spirit
    magic_power life_resistance spirit_resistance damage
  ].freeze

  validates :name, presence: true, uniqueness: true
  # bonus_value: 通常バフ=ステータス補正値 / 特殊バフ=トークンのx(kubikariは未使用)
  validates :bonus_value, numericality: { only_integer: true, in: -999..999 }
  validates :duration_rounds, numericality: { only_integer: true, in: 0..50 }, allow_nil: true
  validates :target_status, inclusion: { in: TARGET_STATUSES }, allow_nil: true
  # 通常バフ(special_type=nil)のみ対象ステータス必須。特殊バフは末尾ポン付けのため不要
  validates :target_status, presence: true, if: -> { special_type.nil? }

  # 判定式計算に必要な数値だけをコピー(nameやspecial_typeはbuff_preset経由で参照するため含めない)
  def build_buff_for(character)
    Buff.new(
      character: character,
      buff_preset: self,
      bonus_value: bonus_value,
      target_status: target_status,
      value_kind: value_kind,
      duration_rounds: duration_rounds,
      remaining_rounds: duration_rounds,
      # 登録直後はactive: falseで作る。オンにした時だけ判定式へ反映される仕様のため、
      # 登録時点で判定式が黙って変わってしまうのを防ぐ（ユーザーが明示的にトグルしてオンにする）
      active: false
    )
  end
end
