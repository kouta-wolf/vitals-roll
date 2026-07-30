require 'rails_helper'

RSpec.describe "Header", type: :request do
  let(:user) { create(:user) }

  describe "ロゴのリンク先" do
    context "未ログインの場合" do
      it "root_pathへのリンクになっている" do
        get root_path
        expect(response.body).to include(%(href="#{root_path}"))
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      it "characters_pathへのリンクになっている" do
        get characters_path
        expect(response.body).to include(%(href="#{characters_path}"))
      end
    end
  end
end
