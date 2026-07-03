require 'rails_helper'

RSpec.describe "Weapons", type: :request do
  let(:user) { create(:user) }

  describe "GET /characters/:character_id/weapons/new" do
    let(:character) { create(:character, user: user) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get new_character_weapon_path(character)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      it "正常にアクセスできる" do
        get new_character_weapon_path(character)
        expect(response).to have_http_status(200)
      end

      it "フォームが表示される" do
        get new_character_weapon_path(character)
        expect(response.body).to include("武器名")
      end

      it "他ユーザーのキャラクターの場合404になる" do
        other_character = create(:character, user: create(:user))
        get new_character_weapon_path(other_character)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "POST /characters/:character_id/weapons" do
    let(:character) { create(:character, user: user) }
    let(:valid_params) do
      { weapon: { name: "テスター・メイス", power: 20, critical: 11, fixed_value: 1, fixed_hit_rate: 0 } }
    end

    let(:invalid_params) do
      { weapon: { name: "" } }
    end

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        post character_weapons_path(character), params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      context "有効なパラメータの場合" do
        it "武器が作成される" do
          expect { post character_weapons_path(character), params: valid_params }.to change(Weapon, :count).by(1)
        end

        it "キャラクター詳細ページにリダイレクトされる" do
          post character_weapons_path(character), params: valid_params
          expect(response).to redirect_to(character_path(character))
        end
      end

      context "無効なパラメータの場合（名前が空欄）" do
        it "武器が作成されない" do
          expect { post character_weapons_path(character), params: invalid_params }.not_to change(Weapon, :count)
        end

        it "422を返す" do
          post character_weapons_path(character), params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "名前以外が空欄の場合" do
        it "デフォルト値で武器が作成される" do
          post character_weapons_path(character), params: { weapon: { name: "素手" } }
          expect(Weapon.last.critical).to eq(10)
        end
      end

      context "他ユーザーのキャラクターに対してPOSTした場合" do
        it "404になり武器が作成されない" do
          other_character = create(:character, user: create(:user))
          expect { post character_weapons_path(other_character), params: valid_params }.not_to change(Weapon, :count)
        end
      end
    end
  end
end
