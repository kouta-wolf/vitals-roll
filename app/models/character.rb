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

  private

  # 無限持続(remaining_rounds: nil)を除いた、増減対象のactiveなバフ
  def active_timed_buffs
    buffs.where(active: true).where.not(remaining_rounds: nil)
  end
end
