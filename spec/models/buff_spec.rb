require 'rails_helper'

RSpec.describe Buff, type: :model do
  describe "正常動作" do
    it "有効なファクトリ(カスタムバフ)を持つか" do
      expect(build(:buff)).to be_valid
    end

    it "有効なファクトリ(プリセット由来バフ)を持つか" do
      expect(build(:buff, :from_preset)).to be_valid
    end
  end

  describe "異常動作" do
    context "基準から1つ壊して無効になるか" do
      it "カスタムバフでnameがnilなら無効になるか" do
        buff = build(:buff, name: nil)
        expect(buff).to be_invalid
        expect(buff.errors[:name]).to be_present
      end

      it "プリセット由来バフはnameがnilでも有効になるか" do
        expect(build(:buff, :from_preset, name: nil)).to be_valid
      end

      it "bonus_valueがnilなら無効になるか" do
        buff = build(:buff, bonus_value: nil)
        expect(buff).to be_invalid
        expect(buff.errors[:bonus_value]).to be_present
      end
    end

    context "target_status" do
      it "target_statusがnilなら無効になるか" do
        buff = build(:buff, target_status: nil)
        expect(buff).to be_invalid
        expect(buff.errors[:target_status]).to be_present
      end

      it "target_statusが許容外の値なら無効になるか" do
        buff = build(:buff, target_status: "unknown")
        expect(buff).to be_invalid
        expect(buff.errors[:target_status]).to be_present
      end
    end
  end

  describe "境界値" do
    context "bonus_value" do
      it "-1000なら無効になるか" do
        buff = build(:buff, bonus_value: -1000)
        expect(buff).to be_invalid
        expect(buff.errors[:bonus_value]).to be_present
      end

      it "-999なら有効になるか" do
        expect(build(:buff, bonus_value: -999)).to be_valid
      end

      it "999なら有効になるか" do
        expect(build(:buff, bonus_value: 999)).to be_valid
      end

      it "1000なら無効になるか" do
        buff = build(:buff, bonus_value: 1000)
        expect(buff).to be_invalid
        expect(buff.errors[:bonus_value]).to be_present
      end
    end

    context "duration_rounds" do
      it "-1なら無効になるか" do
        buff = build(:buff, duration_rounds: -1)
        expect(buff).to be_invalid
        expect(buff.errors[:duration_rounds]).to be_present
      end

      it "0なら有効になるか" do
        expect(build(:buff, duration_rounds: 0)).to be_valid
      end

      it "50なら有効になるか" do
        expect(build(:buff, duration_rounds: 50)).to be_valid
      end

      it "51なら無効になるか" do
        buff = build(:buff, duration_rounds: 51)
        expect(buff).to be_invalid
        expect(buff.errors[:duration_rounds]).to be_present
      end

      it "nilなら有効になるか(無限持続)" do
        expect(build(:buff, duration_rounds: nil)).to be_valid
      end
    end

    context "remaining_rounds" do
      it "-1なら無効になるか" do
        buff = build(:buff, remaining_rounds: -1)
        expect(buff).to be_invalid
        expect(buff.errors[:remaining_rounds]).to be_present
      end

      it "0なら有効になるか" do
        expect(build(:buff, remaining_rounds: 0)).to be_valid
      end

      it "50なら有効になるか" do
        expect(build(:buff, remaining_rounds: 50)).to be_valid
      end

      it "51なら無効になるか" do
        buff = build(:buff, remaining_rounds: 51)
        expect(buff).to be_invalid
        expect(buff.errors[:remaining_rounds]).to be_present
      end

      it "nilなら有効になるか(無限持続)" do
        expect(build(:buff, remaining_rounds: nil)).to be_valid
      end
    end
  end

  describe "アソシエーション" do
    it "characterが未設定なら無効になるか" do
      buff = build(:buff, character: nil)
      expect(buff).to be_invalid
      expect(buff.errors[:character]).to be_present
    end

    it "buff_presetが未設定でも有効になるか" do
      expect(build(:buff, buff_preset: nil)).to be_valid
    end
  end

  describe "#display_name" do
    it "カスタムバフはnameを返すか" do
      buff = build(:buff, name: "カスタムバフ")
      expect(buff.display_name).to eq("カスタムバフ")
    end

    it "プリセット由来バフはbuff_preset.nameを返すか" do
      buff_preset = create(:buff_preset, name: "プリセットバフ")
      buff = build(:buff, :from_preset, buff_preset: buff_preset)
      expect(buff.display_name).to eq("プリセットバフ")
    end
  end
end
