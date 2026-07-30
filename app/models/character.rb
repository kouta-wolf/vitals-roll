class Character < ApplicationRecord
  belongs_to :user
  has_many :weapons, dependent: :destroy
  has_many :buffs, dependent: :destroy

  validates :name, presence: true
  validates :dexterity, :agility, :strength, :vitality, :intelligence, :spirit,
            presence: true, numericality: { only_integer: true, in: 1..999 }

  def advance_round!
    increment!(:current_rounds)
    active_timed_buffs.each { |buff| buff.decrement_remaining_round! }
  end

  def retreat_round!
    return if current_rounds <= 0

    decrement!(:current_rounds)
    active_timed_buffs.each { |buff| buff.increment_remaining_round! }
  end

  def reset_round!
    update!(current_rounds: 0)
    buffs.where.not(duration_rounds: nil).find_each do |buff|
      buff.update!(active: false, remaining_rounds: buff.duration_rounds)
    end
  end

  def hit_formula(weapon)
    base = main_class_level + (dexterity / 6) + weapon.fixed_hit_rate
    "2d6#{signed(base)}#{signed(buff_total_for('dexterity'))}"
  end

  def attack_formula(weapon)
    total = weapon.fixed_value + buff_total_for(%w[strength damage])
    "k#{weapon.power}[#{weapon.critical}]#{signed(total)}#{special_formula_suffix}"
  end

  private

  # 無限持続(remaining_rounds: nil)を除いた、増減対象のactiveなバフ
  def active_timed_buffs
    buffs.where(active: true).where.not(remaining_rounds: nil)
  end

  # 対象ステータスのactiveなバフ合計。
  # value_kind: ability(能力値そのものを上げる)はボーナス換算(合計÷6切り捨て)を経てから加算し、
  # value_kind: fixed(固定値/ボーナス値)はそのまま加算する。
  def buff_total_for(target_statuses)
    scope = buffs.where(active: true, target_status: target_statuses)
    fixed_total = scope.fixed.sum(:bonus_value)
    ability_total = scope.ability.sum(:bonus_value) / 6
    fixed_total + ability_total
  end

  # special_type由来の判定式末尾トークン
  def special_formula_suffix
    "#{critical_ray_suffix}#{kubikari_suffix}"
  end

  # クリティカルレイ: 同時に有効なのは常に1つの前提なのでbonus_valueをそのまま使う
  def critical_ray_suffix
    buff = special_buff_for("critical_ray")
    buff ? "$#{signed(buff.bonus_value)}" : ""
  end

  # 首刈り刀: bonus_valueは使わず固定でr5を付与する
  def kubikari_suffix
    special_buff_for("kubikari") ? "r5" : ""
  end

  def special_buff_for(special_type)
    buffs.joins(:buff_preset).find_by(active: true, buff_presets: { special_type: special_type })
  end

  # 正の値は+を付け、負の値はそのまま(二重符号を避ける)
  def signed(value)
    value >= 0 ? "+#{value}" : value.to_s
  end
end
