class Character < ApplicationRecord
  belongs_to :user
  has_many :weapons, dependent: :destroy
  # inverse_ofを明示すると、ロード済みのbuffsに対する find(id) がSQLを投げずメモリ内走査になり、
  # プリロード済み配列と同一インスタンスが返る。BuffsController#toggleがこれに依存している
  has_many :buffs, dependent: :destroy, inverse_of: :character

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
    # where.notで取り直すと別インスタンスを更新することになりassociationキャッシュが古くなるため、
    # ロード済みbuffsをそのまま絞り込んで更新する(理由の詳細はactive_timed_buffs参照)
    buffs.reject { |buff| buff.duration_rounds.nil? }.each do |buff|
      buff.update!(active: false, remaining_rounds: buff.duration_rounds)
    end
  end

  # 判定式を描画する経路(CharactersController#show/advance_round/retreat_round/reset_round、
  # BuffsController#toggle)では必ず呼ぶこと。呼び忘れるとN+1が復活する。
  #
  # includesではなくPreloaderを使う理由: includesは未実行のRelationにしか効かず、
  # set_characterで取得済みのインスタンスには後付けできないため。
  # なおPreloaderの引数形式はRails 7.0でpositionalからkeywordへ変わった実績があり、
  # 将来のアップグレードで書き換えが必要になる可能性がある。
  def preload_buffs_with_preset!
    ActiveRecord::Associations::Preloader.new(records: [ self ], associations: { buffs: :buff_preset }).call
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

  # 無限持続(remaining_rounds: nil)を除いた、増減対象のactiveなバフ。
  # whereで取り直すとロード済みbuffsとは別インスタンスが返り、呼び出し側の更新が
  # associationキャッシュに反映されず古い値のまま判定式が組まれるためメモリ内で絞る
  def active_timed_buffs
    buffs.select { |buff| buff.active? && !buff.remaining_rounds.nil? }
  end

  # 対象ステータスのactiveなバフ合計。
  # value_kind: ability(能力値そのものを上げる)はボーナス換算(合計÷6切り捨て)を経てから加算し、
  # value_kind: fixed(固定値/ボーナス値)はそのまま加算する。
  # 元はwhere+SQLのSUMで3クエリ発行していたが、判定式1回につきhit/attack両方から呼ばれるため
  # プリロード済みbuffsに対するメモリ内集計に変えてクエリを0本にしている。
  # Array()は、呼び出し側が文字列('dexterity')と配列(%w[strength damage])の両方を渡すため
  def buff_total_for(target_statuses)
    target_statuses = Array(target_statuses)
    scope = buffs.select { |buff| buff.active? && target_statuses.include?(buff.target_status) }
    fixed_total = scope.select(&:fixed?).sum(&:bonus_value)
    ability_total = scope.select(&:ability?).sum(&:bonus_value) / 6
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

  # buffsのロード順(明示的なORDERは付けていないため実質的にid昇順)における最初の1件を返す。
  # 元はjoins+find_byで毎回SQLを発行しており、判定式1回でcritical_ray/kubikariの2回呼ばれていた。
  # buff_presetを参照するため、preload_buffs_with_preset!済みでないとバフ件数分のクエリが発生する
  def special_buff_for(special_type)
    buffs.find { |buff| buff.active? && buff.buff_preset&.special_type == special_type }
  end

  # 正の値は+を付け、負の値はそのまま(二重符号を避ける)
  def signed(value)
    value >= 0 ? "+#{value}" : value.to_s
  end
end
