require 'rails_helper'

RSpec.describe BuffPreset, type: :model do
  describe "正常動作" do
    it "有効なファクトリを持つか" do
      expect(build(:buff_preset)).to be_valid
    end
  end

  describe "異常動作" do
    context "基準から1つ壊して無効になるか" do
      it "nameがnilなら無効になるか" do
        buff_preset = build(:buff_preset, name: nil)
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:name]).to be_present
      end

      it "bonus_valueがnilなら無効になるか" do
        buff_preset = build(:buff_preset, bonus_value: nil)
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:bonus_value]).to be_present
      end
    end

    context "uniqueness" do
      it "同名のバフプリセットが既に存在するなら無効になるか" do
        create(:buff_preset, name: "重複バフ")
        buff_preset = build(:buff_preset, name: "重複バフ")
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:name]).to be_present
      end
    end

    context "target_status" do
      it "通常バフでtarget_statusがnilなら無効になるか" do
        buff_preset = build(:buff_preset, target_status: nil)
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:target_status]).to be_present
      end

      it "target_statusが許容外の値なら無効になるか" do
        buff_preset = build(:buff_preset, target_status: "unknown")
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:target_status]).to be_present
      end

      it "特殊バフはtarget_statusがnilでも有効になるか" do
        expect(build(:buff_preset, :special)).to be_valid
      end
    end

    context "special_type" do
      it "未定義の値を代入するとArgumentErrorになるか" do
        expect { build(:buff_preset, special_type: "unknown") }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#build_buff_for" do
    let(:character) { create(:character) }

    it "value_kindがバフへコピーされるか" do
      preset = create(:buff_preset, target_status: "strength", value_kind: "ability", bonus_value: 12)
      buff = preset.build_buff_for(character)
      expect(buff.value_kind).to eq("ability")
    end

    it "value_kind未指定のプリセットからはfixedのバフが生成されるか" do
      preset = create(:buff_preset, target_status: "strength", bonus_value: 3)
      buff = preset.build_buff_for(character)
      expect(buff.value_kind).to eq("fixed")
    end
  end

  describe "境界値" do
    context "bonus_value" do
      it "-1000なら無効になるか" do
        buff_preset = build(:buff_preset, bonus_value: -1000)
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:bonus_value]).to be_present
      end

      it "-999なら有効になるか" do
        expect(build(:buff_preset, bonus_value: -999)).to be_valid
      end

      it "999なら有効になるか" do
        expect(build(:buff_preset, bonus_value: 999)).to be_valid
      end

      it "1000なら無効になるか" do
        buff_preset = build(:buff_preset, bonus_value: 1000)
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:bonus_value]).to be_present
      end
    end

    context "duration_rounds" do
      it "-1なら無効になるか" do
        buff_preset = build(:buff_preset, duration_rounds: -1)
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:duration_rounds]).to be_present
      end

      it "0なら有効になるか" do
        expect(build(:buff_preset, duration_rounds: 0)).to be_valid
      end

      it "50なら有効になるか" do
        expect(build(:buff_preset, duration_rounds: 50)).to be_valid
      end

      it "51なら無効になるか" do
        buff_preset = build(:buff_preset, duration_rounds: 51)
        expect(buff_preset).to be_invalid
        expect(buff_preset.errors[:duration_rounds]).to be_present
      end

      it "nilなら有効になるか(無限持続)" do
        expect(build(:buff_preset, duration_rounds: nil)).to be_valid
      end
    end
  end
end
