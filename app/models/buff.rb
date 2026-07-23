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
  # 通常バフのみtarget_status必須。特殊プリセット由来(special_type有り)は対象ステータスの概念が無いため不要
  validates :target_status, presence: true, inclusion: { in: TARGET_STATUSES },
                             unless: -> { buff_preset&.special_type.present? }

  # nameは通常カスタムバフのみ持つため、あればそちらを優先しプリセット名にフォールバックする
  def display_name
    name.presence || buff_preset&.name
  end

  def decrement_remaining_round!
    return if remaining_rounds.nil?

    new_remaining_rounds = [ remaining_rounds - 1, 0 ].max
    update!(remaining_rounds: new_remaining_rounds, active: new_remaining_rounds.positive?)
  end

  def increment_remaining_round!
    return if remaining_rounds.nil?

    new_remaining_rounds = duration_rounds.nil? ? remaining_rounds + 1 : [ remaining_rounds + 1, duration_rounds ].min
    update!(remaining_rounds: new_remaining_rounds)
  end

  # オフ→オンへの切り替え時、持続切れ(remaining_rounds: 0)のバフは持続ラウンドを満タンに戻して再アクティブ化する
  def toggle_active!
    if !active? && remaining_rounds == 0 && duration_rounds.present?
      update!(active: true, remaining_rounds: duration_rounds)
    else
      toggle!(:active)
    end
  end
end
