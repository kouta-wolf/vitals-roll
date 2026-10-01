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

      # nilを許すと hit_formula が NoMethodError で落ち、詳細ページ全体が500になる
      it "レベルがnilなら無効になるか" do
        character = build(:character, main_class_level: nil)
        expect(character).to be_invalid
        expect(character.errors[:main_class_level]).to be_present
      end

      it "防護点がnilなら無効になるか" do
        character = build(:character, defense: nil)
        expect(character).to be_invalid
        expect(character.errors[:defense]).to be_present
      end

      it "現在ラウンドがnilなら無効になるか" do
        character = build(:character, current_rounds: nil)
        expect(character).to be_invalid
        expect(character.errors[:current_rounds]).to be_present
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

    it "レベルが0なら無効になるか" do
      character = build(:character, main_class_level: 0)
      expect(character).to be_invalid
      expect(character.errors[:main_class_level]).to be_present
    end

    it "レベルが1なら有効になるか" do
      expect(build(:character, main_class_level: 1)).to be_valid
    end

    it "レベルが15なら有効になるか" do
      expect(build(:character, main_class_level: 15)).to be_valid
    end

    # 上限は敢えて設けていない。上限を超えた既存行があると reset_round! の update! だけが
    # 500になる非対称な壊れ方をするため（詳細は Character のコメント参照）
    it "レベルがフォームの上限(15)を超えていても有効になるか" do
      expect(build(:character, main_class_level: 16)).to be_valid
    end

    it "防護点が1000でも有効になるか（上限を設けていないため）" do
      expect(build(:character, defense: 1000)).to be_valid
    end

    it "防護点が0なら有効になるか" do
      expect(build(:character, defense: 0)).to be_valid
    end

    it "防護点が負の値なら無効になるか" do
      character = build(:character, defense: -1)
      expect(character).to be_invalid
      expect(character.errors[:defense]).to be_present
    end

    it "現在ラウンドが0なら有効になるか（reset_round!が0にするため）" do
      expect(build(:character, current_rounds: 0)).to be_valid
    end

    it "現在ラウンドが負の値なら無効になるか" do
      character = build(:character, current_rounds: -1)
      expect(character).to be_invalid
      expect(character.errors[:current_rounds]).to be_present
    end
  end
end
