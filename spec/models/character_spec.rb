require 'rails_helper'

RSpec.describe Character, type: :model do
  describe "アソシエーション" do
    it "userが無効なら無効となるか" do
      expect(build(:character, user: nil)).to be_invalid
    end
  end

  describe "正常動作" do
    it "有効なファクトリを持つか" do
      expect(build(:character)).to be_valid
    end
  end

  describe "異常動作" do
    context "基準から1つ壊して無効になるか" do
      it "nameがnilなら無効になるか" do
        character = build(:character, name: nil)
        expect(character).to be_invalid
        expect(character.errors[:name]).to be_present
      end

      it "器用度がnilなら無効になるか" do
        character = build(:character, dexterity: nil)
        expect(character).to be_invalid
        expect(character.errors[:dexterity]).to be_present
      end
    end
  end

  describe "境界値" do
    it "器用度が0なら無効になるか" do
      character = build(:character, dexterity: 0)
      expect(character).to be_invalid
      expect(character.errors[:dexterity]).to be_present
    end

    it "器用度が1なら有効になるか" do
      character = build(:character, dexterity: 1)
      expect(character).to be_valid
    end

    it "器用度が999なら有効になるか" do
      character = build(:character, dexterity: 999)
      expect(character).to be_valid
    end

    it "器用度が1000なら無効になるか（入力ミス検知）" do
      character = build(:character, dexterity: 1000)
      expect(character).to be_invalid
      expect(character.errors[:dexterity]).to be_present
    end
  end

  describe "#advance_round!" do
    let(:character) { create(:character, current_rounds: 0) }

    it "activeなバフのremaining_roundsが1減る" do
      buff = create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 3)
      expect { character.advance_round! }.to change { buff.reload.remaining_rounds }.from(3).to(2)
    end

    it "remaining_roundsが1のバフは次のターンで0になりactiveもfalseになる" do
      buff = create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 1)
      character.advance_round!
      buff.reload
      expect(buff.remaining_rounds).to eq(0)
      expect(buff.active).to be false
    end

    it "duration_roundsがnilの無限バフは変化しないか" do
      buff = create(:buff, character: character, active: true, duration_rounds: nil, remaining_rounds: nil)
      expect { character.advance_round! }.not_to change { buff.reload.remaining_rounds }
    end

    it "activeがfalseのバフは対象外で変化しないか" do
      buff = create(:buff, character: character, active: false, duration_rounds: 3, remaining_rounds: 3)
      expect { character.advance_round! }.not_to change { buff.reload.remaining_rounds }
    end

    it "他キャラクターのバフには影響しないか" do
      other_character = create(:character)
      other_buff = create(:buff, character: other_character, active: true, duration_rounds: 3, remaining_rounds: 3)
      character.advance_round!
      expect(other_buff.reload.remaining_rounds).to eq(3)
    end

    it "buffsをロード済みの状態でも、失効直後の同一リクエスト内でattack_formulaへ最新状態が反映されるか(association cacheが古いままにならないか)" do
      weapon = create(:weapon, character: character, power: 25, critical: 10, fixed_value: 1)
      create(:buff, character: character, active: true, target_status: "strength", bonus_value: 2, duration_rounds: 1, remaining_rounds: 1)
      character.buffs.load # 事前ロードしてキャッシュを作っておく(コントローラの挙動を再現)

      character.advance_round!

      expect(character.attack_formula(weapon)).to eq("k25[10]+1")
    end
  end

  describe "#retreat_round!" do
    let(:character) { create(:character, current_rounds: 2) }

    it "activeなバフのremaining_roundsが1増えるか" do
      buff = create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 1)
      expect { character.retreat_round! }.to change { buff.reload.remaining_rounds }.from(1).to(2)
    end

    it "remaining_roundsがduration_roundsに達していればそれ以上増えないか" do
      buff = create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 3)
      expect { character.retreat_round! }.not_to change { buff.reload.remaining_rounds }
    end

    it "duration_roundsがnilの無限バフは変化しないか" do
      buff = create(:buff, character: character, active: true, duration_rounds: nil, remaining_rounds: nil)
      expect { character.retreat_round! }.not_to change { buff.reload.remaining_rounds }
    end

    it "active: false（バフが切れた）は対象外として変化しないか" do
      buff = create(:buff, character: character, active: false, duration_rounds: 3, remaining_rounds: 0)
      character.retreat_round!
      buff.reload
      expect(buff.remaining_rounds).to eq(0)
      expect(buff.active).to be false
    end

    it "他キャラクターのバフには影響しないか" do
      other_character = create(:character)
      other_buff = create(:buff, character: other_character, active: true, duration_rounds: 3, remaining_rounds: 1)
      character.retreat_round!
      expect(other_buff.reload.remaining_rounds).to eq(1)
    end

    it "buffsをロード済みの状態でも、同一リクエスト内で最新のremaining_roundsが読めるか(association cacheが古いままにならないか)" do
      create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 1)
      character.buffs.load # 事前ロードしてキャッシュを作っておく(コントローラの挙動を再現)

      character.retreat_round!

      expect(character.buffs.map(&:remaining_rounds)).to eq([ 2 ])
    end
  end

  describe "#reset_round!" do
    let(:character) { create(:character, current_rounds: 5) }

    it "current_roundsが0に戻るか" do
      expect { character.reset_round! }.to change { character.reload.current_rounds }.from(5).to(0)
    end

    it "持続バフ（duration_roundsあり）のremaining_roundsがduration_roundsに戻るか" do
      buff = create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 1)
      character.reset_round!
      expect(buff.reload.remaining_rounds).to eq(3)
    end

    it "持続バフ（duration_roundsあり）がactive: falseになるか" do
      buff = create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 1)
      character.reset_round!
      expect(buff.reload.active).to be false
    end

    it "無限バフ（duration_roundsがnil）は変化しないか" do
      buff = create(:buff, character: character, active: true, duration_rounds: nil, remaining_rounds: nil)
      character.reset_round!
      buff.reload
      expect(buff.remaining_rounds).to be_nil
      expect(buff.active).to be true
    end

    it "他キャラクターのバフには影響しないか" do
      other_character = create(:character)
      other_buff = create(:buff, character: other_character, active: true, duration_rounds: 3, remaining_rounds: 1)
      character.reset_round!
      expect(other_buff.reload.remaining_rounds).to eq(1)
    end

    it "buffsをロード済みの状態でも、同一リクエスト内で最新のactive状態が読めるか(association cacheが古いままにならないか)" do
      create(:buff, character: character, active: true, duration_rounds: 3, remaining_rounds: 1)
      character.buffs.load # 事前ロードしてキャッシュを作っておく(コントローラの挙動を再現)

      character.reset_round!

      expect(character.buffs.map(&:active)).to eq([ false ])
    end
  end

  describe "#hit_formula" do
    let(:character) { create(:character, main_class_level: 3, dexterity: 12) }
    let(:weapon) { create(:weapon, character: character, fixed_hit_rate: 0) }

    it "バフなしの場合、クラスLv+器用度ボーナスのみの式になるか" do
      expect(character.hit_formula(weapon)).to eq("2d6+5+0")
    end

    it "武器の命中補正が式に反映されるか" do
      weapon.update!(fixed_hit_rate: 2)
      expect(character.hit_formula(weapon)).to eq("2d6+7+0")
    end

    it "対象ステータス(dexterity)のactiveなバフ合計が式に反映されるか" do
      create(:buff, character: character, active: true, target_status: "dexterity", bonus_value: 1)
      create(:buff, character: character, active: true, target_status: "dexterity", bonus_value: 2)
      expect(character.hit_formula(weapon)).to eq("2d6+5+3")
    end

    it "activeがfalseのバフは合算されないか" do
      create(:buff, character: character, active: false, target_status: "dexterity", bonus_value: 5)
      expect(character.hit_formula(weapon)).to eq("2d6+5+0")
    end

    it "対象ステータスが異なるバフ(strength等)は合算されないか" do
      create(:buff, character: character, active: true, target_status: "strength", bonus_value: 5)
      expect(character.hit_formula(weapon)).to eq("2d6+5+0")
    end

    it "バフ合計が負の値でも式に空白や二重符号が入らないか" do
      create(:buff, character: character, active: true, target_status: "dexterity", bonus_value: -3)
      expect(character.hit_formula(weapon)).to eq("2d6+5-3")
      expect(character.hit_formula(weapon)).not_to include(" ")
    end

    it "複数武器があっても武器ごとに正しい式を返すか" do
      other_weapon = create(:weapon, character: character, fixed_hit_rate: -1)
      expect(character.hit_formula(weapon)).to eq("2d6+5+0")
      expect(character.hit_formula(other_weapon)).to eq("2d6+4+0")
    end

    it "能力値上昇バフ(value_kind: ability)はボーナス換算(÷6切り捨て)されて加算されるか" do
      # 器用度値+12 → ボーナス+2
      create(:buff, character: character, active: true, target_status: "dexterity", value_kind: "ability", bonus_value: 12)
      expect(character.hit_formula(weapon)).to eq("2d6+5+2")
    end
  end

  describe "#attack_formula" do
    let(:character) { create(:character) }
    let(:weapon) { create(:weapon, character: character, power: 25, critical: 10, fixed_value: 1) }

    it "バフなしの場合、武器の威力・クリティカル値・固定値のみの式になるか" do
      expect(character.attack_formula(weapon)).to eq("k25[10]+1")
    end

    it "対象ステータス(strength)のactiveなバフ合計が式に反映されるか" do
      create(:buff, character: character, active: true, target_status: "strength", bonus_value: 3)
      expect(character.attack_formula(weapon)).to eq("k25[10]+4")
    end

    it "対象ステータス(damage)のactiveなバフ合計も式に反映されるか" do
      create(:buff, character: character, active: true, target_status: "strength", bonus_value: 3)
      create(:buff, character: character, active: true, target_status: "damage", bonus_value: 2)
      expect(character.attack_formula(weapon)).to eq("k25[10]+6")
    end

    it "activeがfalseのバフは合算されないか" do
      create(:buff, character: character, active: false, target_status: "damage", bonus_value: 5)
      expect(character.attack_formula(weapon)).to eq("k25[10]+1")
    end

    it "対象ステータスが異なるバフ(dexterity等)は合算されないか" do
      create(:buff, character: character, active: true, target_status: "dexterity", bonus_value: 5)
      expect(character.attack_formula(weapon)).to eq("k25[10]+1")
    end

    it "バフ合計を含めた結果が負の値でも式に空白や二重符号が入らないか" do
      create(:buff, character: character, active: true, target_status: "damage", bonus_value: -5)
      expect(character.attack_formula(weapon)).to eq("k25[10]-4")
      expect(character.attack_formula(weapon)).not_to include(" ")
    end

    it "複数武器があっても武器ごとに正しい式を返すか" do
      other_weapon = create(:weapon, character: character, power: 40, critical: 9, fixed_value: 3)
      create(:buff, character: character, active: true, target_status: "strength", bonus_value: 2)
      expect(character.attack_formula(weapon)).to eq("k25[10]+3")
      expect(character.attack_formula(other_weapon)).to eq("k40[9]+5")
    end

    context "value_kind: ability(能力値そのものを上げるバフ)" do
      it "能力値上昇バフはボーナス換算(÷6切り捨て)されて加算されるか" do
        # 筋力値+12 → ボーナス+2
        create(:buff, character: character, active: true, target_status: "strength", value_kind: "ability", bonus_value: 12)
        expect(character.attack_formula(weapon)).to eq("k25[10]+3")
      end

      it "6の倍数でない能力値上昇バフは端数が切り捨てられるか" do
        # 筋力値+8 → 8/6=1 → ボーナス+1
        create(:buff, character: character, active: true, target_status: "strength", value_kind: "ability", bonus_value: 8)
        expect(character.attack_formula(weapon)).to eq("k25[10]+2")
      end

      it "ability(換算あり)とfixed(換算なし)のバフが正しく区別して合算されるか" do
        create(:buff, character: character, active: true, target_status: "strength", value_kind: "ability", bonus_value: 12) # → +2
        create(:buff, character: character, active: true, target_status: "damage",   value_kind: "fixed",   bonus_value: 3)  # → +3
        expect(character.attack_formula(weapon)).to eq("k25[10]+6")
      end

      it "能力値低下バフ(負値)もボーナス換算され二重符号にならないか" do
        # 筋力値-12 → ボーナス-2 → 1-2=-1
        create(:buff, character: character, active: true, target_status: "strength", value_kind: "ability", bonus_value: -12)
        expect(character.attack_formula(weapon)).to eq("k25[10]-1")
        expect(character.attack_formula(weapon)).not_to include(" ")
      end
    end

    context "special_type(critical_ray/kubikari)による特殊接尾辞" do
      it "critical_rayのactiveなバフがあれば末尾に$+xが付与されるか" do
        preset = create(:buff_preset, :special, bonus_value: 1)
        create(:buff, :from_preset, character: character, buff_preset: preset, active: true, target_status: nil)
        expect(character.attack_formula(weapon)).to eq("k25[10]+1$+1")
      end

      it "critical_rayがactive: falseなら付与されないか" do
        preset = create(:buff_preset, :special, bonus_value: 1)
        create(:buff, :from_preset, character: character, buff_preset: preset, active: false, target_status: nil)
        expect(character.attack_formula(weapon)).to eq("k25[10]+1")
      end

      it "kubikariのactiveなバフがあれば末尾にr5が付与されるか" do
        preset = create(:buff_preset, name: "首刈り刀", special_type: "kubikari", target_status: nil, bonus_value: 0)
        create(:buff, :from_preset, character: character, buff_preset: preset, active: true, target_status: nil)
        expect(character.attack_formula(weapon)).to eq("k25[10]+1r5")
      end

      it "kubikariがactive: falseなら付与されないか" do
        preset = create(:buff_preset, name: "首刈り刀", special_type: "kubikari", target_status: nil, bonus_value: 0)
        create(:buff, :from_preset, character: character, buff_preset: preset, active: false, target_status: nil)
        expect(character.attack_formula(weapon)).to eq("k25[10]+1")
      end

      it "critical_rayとkubikariが両方activeな場合、$+xの後にr5が続く順序になるか" do
        critical_ray = create(:buff_preset, :special, bonus_value: 2)
        kubikari = create(:buff_preset, name: "首刈り刀", special_type: "kubikari", target_status: nil, bonus_value: 0)
        create(:buff, :from_preset, character: character, buff_preset: critical_ray, active: true, target_status: nil, bonus_value: 2)
        create(:buff, :from_preset, character: character, buff_preset: kubikari, active: true, target_status: nil)
        expect(character.attack_formula(weapon)).to eq("k25[10]+1$+2r5")
      end
    end
  end
end
