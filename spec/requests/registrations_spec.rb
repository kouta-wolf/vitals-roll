require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "正常にアクセスできるか" do
      get new_user_registration_path
      expect(response).to have_http_status(200)
    end
  end

  describe "登録処理（正常）" do
    it "Userが1件増える + リダイレクトできるか" do
      expect {
        post user_registration_path, params: { user: { email: "new@example.com", password: "password", password_confirmation: "password" } }
      }.to change(User, :count).by(1)
      expect(response).to redirect_to(characters_path)
    end
  end

  describe "登録処理（異常）" do
    it "Userが増えない + 422が返るか" do
      expect {
        post user_registration_path, params: { user: { email: "", password: "password", password_confirmation: "password" } }
      }.not_to change(User, :count)
      expect(response).to have_http_status(422)
    end
  end
end
