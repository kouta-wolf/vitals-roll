class Character < ApplicationRecord
  belongs_to :user
  has_many :weapons, dependent: :destroy
  has_many :buffs, dependent: :destroy

  # 新規作成フォームで武器を同時に登録する(#162)。武器は任意入力。
  # weaponsのカラムにはDBのデフォルト値があり、フォームの数値欄は空にならないため
  # :all_blank では未入力を判定できない。武器名が空で数値もデフォルトのままなら未入力とみなす。
  accepts_nested_attributes_for :weapons, reject_if: :untouched_weapon?

  validates :name, presence: true
  validates :dexterity, :agility, :strength, :vitality, :intelligence, :spirit,
            presence: true, numericality: { only_integer: true, in: 1..999 }
  # DBのデフォルト値だけに頼るとフォームの空欄送信でNULLが入り、判定式の算出が
  # 壊れて詳細ページが500になる(#168)。
  #
  # 上限は設けていない。#168 の時点では reset_round! の update! だけが全属性を検証し
  # advance_round! の increment! は検証を通らなかったため、上限を足すと範囲外の
  # 既存行で片方の操作だけが500になる非対称な壊れ方をしたため。#160 でラウンド操作を
  # クライアント側へ移し、current_rounds の更新経路が combat_state の update! 一本に
  # なったのでその制約は無くなったが、上限の導入は既存データの確認とあわせて別途行う。
  validates :main_class_level, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :defense, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :current_rounds, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def untouched_weapon?(attributes)
    defaults = Weapon.column_defaults.slice("power", "critical", "fixed_value", "fixed_hit_rate")
    attributes["name"].blank? &&
      defaults.all? { |column, default| attributes[column].blank? || attributes[column].to_s == default.to_s }
  end
end
