require 'rails_helper'

RSpec.describe Weapon, type: :model do
  describe "アソシエーション" do
    it "characterが無効なら無効となるか" do
      expect(build(:weapon, character: nil)).to be_invalid
    end
  end

  describe "正常動作" do
    it "有効なファクトリを持つか" do
      expect(build(:weapon)).to be_valid
    end
  end

  describe "異常動作" do
    context "基準から1つ壊して無効になるか" do
      it "nameがnilなら無効になるか" do
        weapon = build(:weapon, name: nil)
        expect(weapon).to be_invalid
        expect(weapon.errors[:name]).to be_present
      end
    end
  end

  describe "境界値" do
    it "クリティカル値が2なら無効になるか" do
      weapon = build(:weapon, critical: 2)
      expect(weapon).to be_invalid
      expect(weapon.errors[:critical]).to be_present
    end

    it "クリティカル値が3なら有効になるか" do
      weapon = build(:weapon, critical: 3)
      expect(weapon).to be_valid
    end

    it "クリティカル値が13なら有効になるか" do
      weapon = build(:weapon, critical: 13)
      expect(weapon).to be_valid
    end

    it "クリティカル値が14なら無効になるか" do
      weapon = build(:weapon, critical: 14)
      expect(weapon).to be_invalid
      expect(weapon.errors[:critical]).to be_present
    end
  end

  
end
