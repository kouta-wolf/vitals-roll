module BuffsHelper
  TARGET_STATUS_LABELS = {
    "dexterity" => "器用度（DEX）",
    "agility" => "敏捷度（AGI）",
    "strength" => "筋力（STR）",
    "vitality" => "生命力（VIT）",
    "intelligence" => "知力（INT）",
    "spirit" => "精神力（MND）",
    "magic_power" => "魔法力",
    "life_resistance" => "生命抵抗力",
    "spirit_resistance" => "精神抵抗力",
    "damage" => "ダメージ"
  }.freeze

  def target_status_options
    Buff::TARGET_STATUSES.map { |status| [ TARGET_STATUS_LABELS.fetch(status), status ] }
  end
end
