class Weapon < ApplicationRecord
  belongs_to :character

  before_validation :fill_default_values

  validates :name, presence: true
  validates :power, numericality: { only_integer: true, in: 0..500 }
  validates :critical, numericality: { only_integer: true, in: 3..13 }
  validates :fixed_value, numericality: { only_integer: true, in: -10..100 }
  validates :fixed_hit_rate, numericality: { only_integer: true, in: -10..10 }

  private

  def fill_default_values
    self.power ||= 0
    self.critical ||= 10
    self.fixed_value ||= 0
    self.fixed_hit_rate ||= 0
  end
end
