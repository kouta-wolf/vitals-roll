require 'rails_helper'

RSpec.describe "Characters", type: :request do
  let(:user) { create(:user) }

  describe "GET /characters" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get characters_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "正常にアクセスできる" do
        get characters_path
        expect(response).to have_http_status(200)
      end

      it "自分が所有するキャラクターが表示される" do
        create(:character, user: user, name: "マイ・キャラ")
        get characters_path
        expect(response.body).to include("マイ・キャラ")
      end

      it "他ユーザーのキャラクターは表示されない" do
        other_user = create(:user)
        create(:character, user: other_user, name: "ヨソ・キャラ")
        get characters_path
        expect(response.body).not_to include("ヨソ・キャラ")
      end

      it "キャラクターが1件もない場合は空状態が表示される" do
        get characters_path
        expect(response.body).to include("まだキャラクターがいません")
      end
    end
  end

  describe "GET /characters/new" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get new_character_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "正常にアクセスできる" do
        get new_character_path
        expect(response). to have_http_status(200)
      end

      it "フォームが表示される" do
        get new_character_path
        expect(response.body).to include("キャラクター名")
      end
    end
  end

  describe "POST /characters" do
    let(:valid_params) do
      {
        character: {
          name: "アルフォンス", race: "ヒューマン", main_class: "ファイター", main_class_level: 3,
          dexterity: 12, agility: 10, strength: 14,
          vitality: 11, intelligence: 8, spirit: 9, defense: 4
        }
      }
    end

    let(:invalid_params) do
      { character: { name: "", dexterity: nil, agility: nil, strength: nil, vitality: nil, intelligence: nil, spirit: nil } }
    end

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        post characters_path, params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      context "有効なパラメータの場合" do
        it "キャラクターが1件増える" do
          expect { post characters_path, params: valid_params }.to change(user.characters, :count).by(1)
        end

        it "一覧ページにリダイレクトされる" do
          post characters_path, params: valid_params
          expect(response).to redirect_to(characters_path)
        end

        it "フラッシュメッセージが表示される" do
          post characters_path, params: valid_params
          expect(flash[:notice]).to eq("キャラクターを作成しました")
        end
      end

      context "無効なパラメータの場合" do
        it "キャラクター数が変わらない" do
          expect {
            post characters_path, params: invalid_params
          }.not_to change(user.characters, :count)
        end

        it "422を返してフォームを再表示する" do
          post characters_path, params: invalid_params
          expect(response).to have_http_status(422)
        end

        it "エラーメッセージが表示される" do
          post characters_path, params: invalid_params
          expect(response.body).to include("入力に誤りがあります")
        end
      end
    end
  end

  describe "GET /characters/:id" do
    let(:user_character) { create(:character, user: user) }
    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get character_path(user_character)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン済の場合" do
      before {sign_in user}

      it "正常にアクセスできる(200)" do
        get character_path(user_character)
        expect(response).to have_http_status(200)
      end

      it "正常に内容が表示される" do
        get character_path(user_character)
        expect(response.body).to include("テスター・ドラゴン")
      end

      it "他のユーザーのキャラを閲覧できないこと" do
        other_user = create(:user)
        other_character = create(:character, user: other_user, name: "ヨソ・キャラ")
        get character_path(other_character)
        expect(response).to have_http_status(404)
      end
    end
  end
end
