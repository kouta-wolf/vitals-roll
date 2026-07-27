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
    "k#{weapon.power}[#{weapon.critical}]#{signed(total)}"
  end

  private

  # 無限持続(remaining_rounds: nil)を除いた、増減対象のactiveなバフ
  def active_timed_buffs
    buffs.where(active: true).where.not(remaining_rounds: nil)
  end

  def buff_total_for(target_statuses)
    buffs.where(active: true, target_status: target_statuses).sum(:bonus_value)
  end

  # 正の値は+を付け、負の値はそのまま(二重符号を避ける)
  def signed(value)
    value >= 0 ? "+#{value}" : value.to_s
  end
end
