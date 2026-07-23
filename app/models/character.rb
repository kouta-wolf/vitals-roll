class Character < ApplicationRecord
  belongs_to :user
  has_many :weapons, dependent: :destroy
  has_many :buffs, dependent: :destroy

  validates :name, presence: true
  validates :dexterity, :agility, :strength, :vitality, :intelligence, :spirit,
            presence: true, numericality: { only_integer: true, in: 1..999 }

  def advance_round!
    increment!(:current_rounds)
  end

  def retreat_round!
    return if current_rounds <= 0

    decrement!(:current_rounds)
  end
end
