require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  describe "GET /users/password/new" do
    it "正常にアクセスできるか" do
      get new_user_password_path
      expect(response).to have_http_status(200)
    end
  end

  describe "リセット申請処理" do
    let!(:user) { create(:user) }

    it "登録済みメールアドレスでメールが1通送信される + リダイレクトできるか" do
      expect {
        post user_password_path, params: { user: { email: user.email } }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "未登録メールアドレスでもメールは送信されない + 登録済みと同じ応答を返すか（paranoidモード）" do
      expect {
        post user_password_path, params: { user: { email: "unknown@example.com" } }
      }.not_to change { ActionMailer::Base.deliveries.count }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "リセット実行処理" do
    let!(:user) { create(:user) }
    let!(:token) { user.send_reset_password_instructions }

    it "有効なトークンでパスワードを更新できるか" do
      put user_password_path, params: {
        user: {
          reset_password_token: token,
          password: "new_password",
          password_confirmation: "new_password"
        }
      }
      expect(response).to redirect_to(characters_path)
      expect(user.reload.valid_password?("new_password")).to be true
    end

    it "無効なトークンでは更新できず422が返るか" do
      put user_password_path, params: {
        user: {
          reset_password_token: "invalid_token",
          password: "new_password",
          password_confirmation: "new_password"
        }
      }
      expect(response).to have_http_status(422)
      expect(user.reload.valid_password?("new_password")).to be false
    end
  end
end
