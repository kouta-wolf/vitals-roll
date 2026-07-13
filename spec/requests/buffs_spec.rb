require 'rails_helper'

RSpec.describe "Buffs", type: :request do
  let(:user) { create(:user) }
  let(:character) { create(:character, user: user) }
  let(:buff_preset) { create(:buff_preset, name: "マッスルベアー", target_status: "strength", bonus_value: 12, duration_rounds: 3) }
  let(:valid_params) { { buff: { buff_preset_id: buff_preset.id } } }

  describe "POST /characters/:character_id/buffs" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        post character_buffs_path(character), params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      context "有効なプリセットIDの場合" do
        it "バフが1件増える" do
          expect { post character_buffs_path(character), params: valid_params }.to change(character.buffs, :count).by(1)
        end

        it "プリセットの値がスナップショットとしてコピーされる" do
          post character_buffs_path(character), params: valid_params
          buff = character.buffs.last
          expect(buff).to have_attributes(
            buff_preset_id: buff_preset.id,
            bonus_value: 12,
            target_status: "strength",
            duration_rounds: 3,
            remaining_rounds: 3,
            active: true
          )
        end

        it "キャラクター詳細ページにリダイレクトされる" do
          post character_buffs_path(character), params: valid_params
          expect(response).to redirect_to(character_path(character))
        end

        it "フラッシュメッセージが表示される" do
          post character_buffs_path(character), params: valid_params
          expect(flash[:notice]).to eq("バフを登録しました")
        end

        it "Turbo Stream形式でリクエストするとバフ一覧に行が追加される" do
          post character_buffs_path(character), params: valid_params, as: :turbo_stream
          expect(response.body).to include(buff_preset.name)
        end
      end

      context "存在しないプリセットIDの場合" do
        it "404になりバフが作成されない" do
          expect {
            post character_buffs_path(character), params: { buff: { buff_preset_id: -1 } }
          }.not_to change(character.buffs, :count)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "認可チェック" do
        it "他ユーザーのキャラクターに対してPOSTした場合404になりバフが作成されない" do
          other_character = create(:character, user: create(:user))
          expect {
            post character_buffs_path(other_character), params: valid_params
          }.not_to change(Buff, :count)
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
