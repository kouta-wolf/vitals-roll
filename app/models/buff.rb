class Buff < ApplicationRecord
  belongs_to :character
  belongs_to :buff_preset, optional: true

  # buff_presetsと同じ対象ステータス一覧を共有する
  TARGET_STATUSES = BuffPreset::TARGET_STATUSES

  # bonus_valueの単位。詳細はBuffPreset側のenum定義を参照
  enum :value_kind, {
    fixed:   "fixed",
    ability: "ability"
  }, default: :fixed

  # プリセット由来はbuff_preset.name経由で参照するためnameを持たない
  validates :name, presence: true, if: -> { buff_preset.nil? }
  validates :bonus_value, numericality: { only_integer: true, in: -999..999 }
  # DBは NOT NULL なので、nil が来るとバリデーションを通らず NotNullViolation(500)になる。
  # 外部から直接更新される経路(#159 の combat_state)があるため422で返せるようにする
  validates :active, inclusion: { in: [ true, false ] }
  validates :duration_rounds, numericality: { only_integer: true, in: 0..50 }, allow_nil: true
  validates :remaining_rounds, numericality: { only_integer: true, in: 0..50 }, allow_nil: true
  # 通常バフのみtarget_status必須。特殊プリセット由来(special_type有り)は対象ステータスの概念が無いため不要
  validates :target_status, presence: true, inclusion: { in: TARGET_STATUSES },
                             unless: -> { buff_preset&.special_type.present? }
end
