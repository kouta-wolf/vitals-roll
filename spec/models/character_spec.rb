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
end
