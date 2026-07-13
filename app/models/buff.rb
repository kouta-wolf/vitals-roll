class Buff < ApplicationRecord
  belongs_to :character
  belongs_to :buff_preset, optional: true

  # buff_presetsと同じ対象ステータス一覧を共有する
  TARGET_STATUSES = BuffPreset::TARGET_STATUSES

  # プリセット由来はbuff_preset.name経由で参照するためnameを持たない
  validates :name, presence: true, if: -> { buff_preset.nil? }
  validates :bonus_value, numericality: { only_integer: true, in: -999..999 }
  validates :duration_rounds, numericality: { only_integer: true, in: 0..50 }, allow_nil: true
  validates :remaining_rounds, numericality: { only_integer: true, in: 0..50 }, allow_nil: true
  # special_typeを持たないため、通常バフのみ(target_status必須)
  validates :target_status, presence: true, inclusion: { in: TARGET_STATUSES }

  # display_name/special_typeの参照方法は次issueで検討
  def display_name
    buff_preset&.name || name
  end
end
