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

        it "キャラクター編集ページにリダイレクトされる" do
          post character_weapons_path(character), params: valid_params
          expect(response).to redirect_to(edit_character_path(character))
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

  describe "GET /characters/:character_id/weapons/:id/edit" do
    let(:user_character) { create(:character, user: user) }
    let(:user_weapon) { create(:weapon, character: user_character) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get edit_character_weapon_path(user_character, user_weapon)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      it "正常に内容が表示される" do
        get edit_character_weapon_path(user_character, user_weapon)
        expect(response.body).to include("テストソード")
      end

      it "他ユーザーのキャラクターの場合404になる" do
        other_character = create(:character, user: create(:user))
        other_weapon = create(:weapon, character: other_character)
        get edit_character_weapon_path(other_character, other_weapon)
        expect(response).to have_http_status(404)
      end

      it "自分の別キャラクターに紐づく武器IDを指定した場合404になる" do
        another_character = create(:character, user: user)
        get edit_character_weapon_path(another_character, user_weapon)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "PATCH /characters/:character_id/weapons/:id" do
    let(:character) { create(:character, user: user) }
    let(:weapon) { create(:weapon, character: character) }
    let(:valid_params) do
      { weapon: { name: "テスター・メイス", power: 20, critical: 11, fixed_value: 1, fixed_hit_rate: 0 } }
    end

    let(:invalid_params) do
      { weapon: { name: "" } }
    end

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        patch character_weapon_path(character, weapon), params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      context "有効なパラメータの場合" do
        it "有効なパラメータで更新される" do
          patch character_weapon_path(character, weapon), params: valid_params
          expect(response).to have_http_status(302)
        end

        it "武器の内容が更新される" do
          expect {
            patch character_weapon_path(character, weapon), params: valid_params
          }.to change { weapon.reload.name }.to("テスター・メイス")
        end

        it "更新後メッセージが表示される" do
          patch character_weapon_path(character, weapon), params: valid_params
          expect(flash[:notice]).to eq("武器を更新しました")
        end

        it "更新後キャラクター編集ページへリダイレクトされる" do
          patch character_weapon_path(character, weapon), params: valid_params
          expect(response).to redirect_to(edit_character_path(character))
        end
      end

      context "無効なパラメータの場合" do
        it "無効なパラメータで更新されない" do
          patch character_weapon_path(character, weapon), params: invalid_params
          expect(response).to have_http_status(422)
        end

        it "更新できない場合エラーメッセージが表示される" do
          patch character_weapon_path(character, weapon), params: invalid_params
          expect(response.body).to include("入力に誤りがあります")
        end

        it "更新出来ない場合、DBの値が変わっていない" do
          expect { patch character_weapon_path(character, weapon), params: invalid_params }.not_to change { weapon.reload.name }
        end
      end

      context "認可チェック" do
        it "他のユーザーの武器を編集できない" do
          other_user = create(:user)
          other_character = create(:character, user: other_user, name: "ヨソ・キャラ")
          other_weapon = create(:weapon, character: other_character)
          patch character_weapon_path(other_character, other_weapon), params: valid_params
          expect(response).to have_http_status(404)
        end

        it "自分の別キャラクターに紐づく武器IDを指定した場合編集できない" do
          another_character = create(:character, user: user)
          patch character_weapon_path(another_character, weapon), params: valid_params
          expect(response).to have_http_status(404)
        end
      end
    end
  end

  describe "DELETE /characters/:character_id/weapons/:id" do
    let(:character) { create(:character, user: user) }
    let!(:weapon) { create(:weapon, character: character) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        delete character_weapon_path(character, weapon)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      it "削除に成功する" do
        delete character_weapon_path(character, weapon)
        expect(response).to have_http_status(:found)
      end

      it "武器が削除される" do
        expect { delete character_weapon_path(character, weapon) }.to change(Weapon, :count).by(-1)
      end

      it "キャラクター編集ページにリダイレクトされる" do
        delete character_weapon_path(character, weapon)
        expect(response).to redirect_to(edit_character_path(character))
      end

      it "削除後メッセージが表示される" do
        delete character_weapon_path(character, weapon)
        expect(flash[:notice]).to eq("武器を削除しました")
      end

      context "認可チェック" do
        it "存在しない武器idを指定した場合404になり削除されない" do
          expect {
            delete character_weapon_path(character, id: -1)
          }.not_to change(Weapon, :count)
          expect(response).to have_http_status(:not_found)
        end

        it "他ユーザーのキャラクターの武器を削除できない" do
          other_character = create(:character, user: create(:user))
          other_weapon = create(:weapon, character: other_character)
          expect {
            delete character_weapon_path(other_character, other_weapon)
          }.not_to change(Weapon, :count)
          expect(response).to have_http_status(:not_found)
        end

        it "自分の別キャラクターに紐づく武器IDを指定した場合削除できない" do
          another_character = create(:character, user: user)
          expect {
            delete character_weapon_path(another_character, weapon)
          }.not_to change(Weapon, :count)
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
