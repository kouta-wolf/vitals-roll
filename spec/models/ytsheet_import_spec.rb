require "rails_helper"

RSpec.describe YtsheetImport do
  let(:sheet) { JSON.parse(file_fixture("ytsheet_sw25.json").read) }
  let(:import) { described_class.new(json: sheet.to_json) }

  describe "#character_attributes" do
    it "基本情報と防護点を読み込む" do
      expect(import.character_attributes).to include(
        name: "アルフォンス", race: "人間", main_class: "ファイター", main_class_level: 7, defense: 5
      )
    end

    it "能力値は増強・装備の補正を含めた実効値にする" do
      expect(import.character_attributes).to include(
        dexterity: 22, agility: 15, strength: 20, vitality: 17, intelligence: 15, spirit: 17
      )
    end
  end

  describe "#weapon_attributes" do
    it "1本目の武器を、判定式がゆとシートⅡの合計値と一致するように換算する" do
      # 命中: 冒険者レベル7 + DEXボーナス3（22÷6） + 命中補正2 = 合計12
      expect(import.weapon_attributes).to eq(
        name: "魔剣〈テストソード〉", power: 17, critical: 10, fixed_value: 12, fixed_hit_rate: 2
      )
    end

    it "アイコン記法だけの武器名からも記法を取り除く" do
      sheet["weapon1Name"] = "[魔]〈バスタードソード+1〉"
      expect(import.weapon_attributes[:name]).to eq("〈バスタードソード+1〉")
    end

    it "1本目の武器名が空なら、名前のある次の武器を使う" do
      sheet["weapon1Name"] = ""
      expect(import.weapon_attributes[:name]).to eq("〈バスタードソード+1〉")
    end

    it "武器が無ければ nil を返す" do
      sheet["weaponNum"] = "0"
      expect(import.weapon_attributes).to be_nil
    end
  end

  describe "#skipped_weapon_count" do
    it "名前のある武器のうち、読み込まなかった本数を返す" do
      expect(import.skipped_weapon_count).to eq(1)
    end

    it "武器が無ければ0を返す" do
      sheet["weaponNum"] = "0"
      expect(import.skipped_weapon_count).to eq(0)
    end
  end

  describe "バリデーション" do
    it "ゆとシートⅡ（SW2.5）のJSONなら有効" do
      expect(import).to be_valid
    end

    def errors_for(json)
      described_class.new(json: json).tap(&:valid?).errors.full_messages
    end

    it "空なら無効" do
      expect(errors_for("")).to eq([ "JSONを貼り付けてください" ])
    end

    it "JSONとして読めなければ無効" do
      expect(errors_for("{\"characterName\": ")).to include(a_string_including("JSONとして読み込めませんでした"))
    end

    it "オブジェクト以外のJSONなら無効" do
      expect(errors_for("[1, 2]")).to include(a_string_including("JSONとして読み込めませんでした"))
    end

    it "ゆとシートⅡがエラーを返していれば、そのメッセージを出す" do
      json = { result: "error", message: "シートが見つかりませんでした。", data: nil }.to_json
      expect(errors_for(json)).to eq([ "ゆとシートⅡがエラーを返しています（シートが見つかりませんでした。）" ])
    end

    it "SW2.5以外のシートなら無効" do
      expect(errors_for(sheet.merge("gameVersion" => "2.0").to_json)).to eq([ "ソード・ワールド2.5のキャラクターシートではありません" ])
    end

    it "能力値が欠けていれば無効" do
      expect(errors_for(sheet.except("sttMnd").to_json)).to eq([ "能力値を読み込めませんでした" ])
    end

    it "大きすぎれば無効" do
      json = sheet.merge("padding" => "a" * described_class::MAX_BYTES).to_json
      expect(errors_for(json)).to eq([ "JSONが大きすぎます" ])
    end
  end
end
