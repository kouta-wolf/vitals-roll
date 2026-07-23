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
  end
end
