require 'rails_helper'

RSpec.describe "Top", type: :request do
  describe "GET /" do
    context "未ログインの場合" do
      it "正常にアクセスできるか" do
        get root_path
        expect(response).to have_http_status(200)
      end
    end

    context "ログイン済の場合" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "characters_pathへリダイレクトされる" do
        get root_path
        expect(response).to redirect_to(characters_path)
      end
    end
  end
end
