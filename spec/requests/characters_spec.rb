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
end