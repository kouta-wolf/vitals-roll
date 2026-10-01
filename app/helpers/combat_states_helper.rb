module CombatStatesHelper
  # キャラクター詳細ページの初期HTMLへ埋め込む、戦闘操作に必要なデータ一式。
  # TypeScript側の CombatStateData（app/javascript/domain/combatState.ts）と対応するため
  # キー名はcamelCaseで揃える。
  #
  # buff_preset を includes で引いているのはN+1を避けるため。判定式をサーバ側で
  # 組んでいた頃は同一リクエスト内で更新したインスタンスを読み直す必要があり
  # Preloader を使っていたが、ここは読み取り専用なので includes で足りる。
  def combat_state_data(character, weapons)
    {
      character: character_data(character),
      weapons: weapons.map { |weapon| weapon_data(weapon) },
      buffs: character.buffs.includes(:buff_preset).map { |buff| buff_data(buff) },
      saveUrl: character_combat_state_path(character),
      # sendBeacon はヘッダを付けられないため、CSRFトークンはボディへ入れて送る
      csrfToken: form_authenticity_token,
      # バフのCRUDはRails側のページ遷移のまま。Reactからはリンク/フォームのURLとして使う
      buffPathPrefix: character_buffs_path(character)
    }
  end

  private

  def character_data(character)
    {
      id: character.id,
      name: character.name,
      race: character.race,
      mainClass: character.main_class,
      mainClassLevel: character.main_class_level,
      dexterity: character.dexterity,
      agility: character.agility,
      strength: character.strength,
      vitality: character.vitality,
      intelligence: character.intelligence,
      spirit: character.spirit,
      defense: character.defense,
      currentRounds: character.current_rounds
    }
  end

  def weapon_data(weapon)
    {
      id: weapon.id,
      name: weapon.name,
      power: weapon.power,
      critical: weapon.critical,
      fixedValue: weapon.fixed_value,
      fixedHitRate: weapon.fixed_hit_rate
    }
  end

  def buff_data(buff)
    {
      id: buff.id,
      name: buff.name,
      active: buff.active,
      targetStatus: buff.target_status,
      bonusValue: buff.bonus_value,
      valueKind: buff.value_kind,
      durationRounds: buff.duration_rounds,
      remainingRounds: buff.remaining_rounds,
      buffPreset: buff.buff_preset && {
        id: buff.buff_preset.id,
        name: buff.buff_preset.name,
        specialType: buff.buff_preset.special_type
      }
    }
  end
end
