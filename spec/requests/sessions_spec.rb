require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }

  describe "GET users/sign_in" do
    it "正常にアクセスできるか" do
      get user_session_path
      expect(response).to have_http_status(200)
    end
  end

  describe "POST /users/sign_in（ログイン)" do
    it "正しい認証情報ならログイン後ページにリダイレクトされる" do
      post user_session_path, params: {
        user: { email: user.email, password: user.password }
      }
      expect(response).to redirect_to(characters_path)
    end

    it "誤ったパスワードならログインページが再表示される" do
      post user_session_path, params: {
        user: { email: user.email, password: "wrong" }
      }
      expect(response).to have_http_status(422) # 失敗時は再描画
    end
  end

  describe "未ログイン時のアクセス制御" do
    it "保護ページにアクセスするとログインページへリダイレクトされる" do
      get characters_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "DELETE /users/sign_out（ログアウト）" do
    it "ログアウトできる" do
      sign_in user
      delete destroy_user_session_path
      expect(response).to redirect_to(root_path)
    end
  end
end
