# ゆとシートⅡ（SW2.5）のキャラクターJSONから、新規作成フォームへ入れる値を組み立てる(#194)。
#
# 保存はしない。取り込んだ値はフォームに表示し、ユーザーが確認してから「作成する」で保存する。
# ゆとシートⅡ側の仕様変更や想定外のデータで、気づかないまま誤った値が保存されるのを防ぐため。
class YtsheetImport
  include ActiveModel::Model

  MAX_BYTES = 1.megabyte

  # vitals-roll の能力値 => [ゆとシートⅡの能力値, 増強・装備の添字]
  ABILITIES = {
    dexterity:    [ "sttDex", "A" ],
    agility:      [ "sttAgi", "B" ],
    strength:     [ "sttStr", "C" ],
    vitality:     [ "sttVit", "D" ],
    intelligence: [ "sttInt", "E" ],
    spirit:       [ "sttMnd", "F" ]
  }.freeze

  attr_accessor :json

  validate :json_must_be_ytsheet_sw25

  def character_attributes
    attributes = {
      name: data["characterName"],
      race: data["race"],
      main_class: weapon&.dig("Class"),
      main_class_level: integer(data["level"]),
      defense: integer(data["defenseTotal1Def"])
    }
    ABILITIES.each_key { |ability| attributes[ability] = ability_value(ability) }
    attributes
  end

  # 判定式がゆとシートⅡの命中・ダメージの合計値と一致するように換算する。
  #
  # vitals-roll の判定式は「命中 = 冒険者レベル + DEXボーナス + 命中補正」「ダメージ = 固定値 + バフ」で、
  # ゆとシートⅡは技能レベル・武器習熟・専用化などを含んだ合計値（AccTotal / DmgTotal）を持つ。
  # 内訳は再現せず、差分を命中補正・固定値へまとめて入れる。
  def weapon_attributes
    return nil if weapon.nil?

    level = integer(data["level"]) || 0
    dexterity = ability_value(:dexterity) || 0
    accuracy_total = integer(weapon["AccTotal"])

    {
      name: weapon_name(weapon["Name"]),
      power: integer(weapon["Rate"]),
      critical: integer(weapon["Crit"]),
      fixed_value: integer(weapon["DmgTotal"]),
      fixed_hit_rate: accuracy_total && accuracy_total - (level + dexterity.div(6))
    }
  end

  # フォームの武器欄は1本分のため、2本目以降は読み込まない
  def skipped_weapon_count
    [ weapons.size - 1, 0 ].max
  end

  private

  def data
    @data ||= begin
      parsed = JSON.parse(json.to_s)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end
  end

  def json_must_be_ytsheet_sw25
    if json.blank?
      errors.add(:base, "JSONを貼り付けてください")
    elsif json.bytesize > MAX_BYTES
      errors.add(:base, "JSONが大きすぎます")
    elsif data.empty?
      errors.add(:base, "JSONとして読み込めませんでした。表示された内容をすべてコピーしているか確認してください")
    elsif data["result"] == "error"
      errors.add(:base, "ゆとシートⅡがエラーを返しています（#{data["message"]}）")
    elsif data["gameVersion"] != "2.5"
      errors.add(:base, "ソード・ワールド2.5のキャラクターシートではありません")
    elsif ABILITIES.values.any? { |key, _| integer(data[key]).nil? }
      errors.add(:base, "能力値を読み込めませんでした")
    end
  end

  def ability_value(ability)
    key, suffix = ABILITIES.fetch(ability)
    base = integer(data[key])
    return nil if base.nil?

    # 増強（腕輪など）と装備による補正を含めた実効値。ゆとシートⅡのボーナス計算と同じ
    base + integer(data["sttAdd#{suffix}"]).to_i + integer(data["sttEquip#{suffix}"]).to_i
  end

  # 武器名が入っている武器を、ゆとシートⅡの並び順で返す
  def weapons
    @weapons ||= (1..integer(data["weaponNum"]).to_i).filter_map do |n|
      attributes = data.select { |key, _| key.start_with?("weapon#{n}") }
                       .transform_keys { |key| key.delete_prefix("weapon#{n}") }
      attributes if attributes["Name"].present?
    end
  end

  def weapon
    weapons.first
  end

  # ゆとシートⅡの記法を取り除く。
  #   [魔剣〈テストソード〉#6cjf5q] … アイテムシートへのリンク → 魔剣〈テストソード〉
  #   [魔] [刃] など                  … 装備の種別を表すアイコン → 削除
  def weapon_name(raw)
    raw.to_s
       .gsub(/\[([^\[\]#]+)#[^\[\]]*\]/, '\1')
       .gsub(/\[[^\[\]]{1,2}\]/, "")
       .strip
  end

  def integer(value)
    Integer(value.to_s, 10, exception: false)
  end
end
