require "rails_helper"

RSpec.describe "CharacterImports", type: :request do
  let(:user) { create(:user) }
  let(:sheet_json) { file_fixture("ytsheet_sw25.json").read }

  describe "POST /character_import" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        post character_import_path, params: { ytsheet_import: { json: sheet_json } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      context "ゆとシートⅡ（SW2.5）のJSONの場合" do
        it "保存はせず、読み込んだ値を新規作成フォームに入れて表示する" do
          expect {
            post character_import_path, params: { ytsheet_import: { json: sheet_json } }
          }.not_to change(Character, :count)

          expect(response).to have_http_status(200)
          html = Nokogiri::HTML(response.body)
          expect(html.at_css("#character_name")["value"]).to eq("アルフォンス")
          expect(html.at_css("#character_dexterity")["value"]).to eq("22")
          expect(html.at_css("#character_main_class_level")["value"]).to eq("7")
          expect(html.at_css("input[name='character[weapons_attributes][0][name]']")["value"]).to eq("魔剣〈テストソード〉")
          expect(html.at_css("input[name='character[weapons_attributes][0][fixed_hit_rate]']")["value"]).to eq("2")
        end

        it "読み込まなかった武器の本数を案内する" do
          post character_import_path, params: { ytsheet_import: { json: sheet_json } }
          expect(response.body).to include("残り1本は作成後に編集画面から追加できます")
        end

        it "読み込みフォームはTurboを使わずに送信する" do
          # Turboは成功したフォーム送信にリダイレクトを求め、200のHTMLを描画しない。
          # request spec ではTurboが動かず検出できないため、属性で確かめる
          get new_character_path
          form = Nokogiri::HTML(response.body).at_css("form[action='#{character_import_path}']")
          expect(form["data-turbo"]).to eq("false")
        end

        it "貼り付け欄は空に戻す" do
          post character_import_path, params: { ytsheet_import: { json: sheet_json } }
          html = Nokogiri::HTML(response.body)
          expect(html.at_css("#ytsheet_import_json").text).to be_blank
        end

        it "表示されたフォームのまま送信すると、キャラクターと武器が作成される" do
          post character_import_path, params: { ytsheet_import: { json: sheet_json } }
          form = Nokogiri::HTML(response.body).at_css("form[action='#{characters_path}']")
          params = form.css("input[name^='character']").to_h { |input| [ input["name"], input["value"] ] }

          expect {
            post characters_path, params: params
          }.to change(user.characters, :count).by(1).and change(Weapon, :count).by(1)
          expect(user.characters.last.weapons.sole).to have_attributes(name: "魔剣〈テストソード〉", fixed_value: 12, fixed_hit_rate: 2)
        end
      end

      context "読み込めないJSONの場合" do
        it "422を返し、エラーと貼り付けた内容を残したフォームを表示する" do
          post character_import_path, params: { ytsheet_import: { json: "{\"characterName\": " } }

          expect(response).to have_http_status(422)
          expect(response.body).to include("JSONとして読み込めませんでした")
          html = Nokogiri::HTML(response.body)
          expect(html.at_css("#ytsheet_import_json").text).to include("characterName")
          expect(html.at_css("details[open]")).to be_present
        end
      end
    end
  end
end
