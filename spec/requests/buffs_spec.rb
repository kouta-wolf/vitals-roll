require 'rails_helper'

RSpec.describe "Buffs", type: :request do
  let(:user) { create(:user) }
  let(:character) { create(:character, user: user) }
  let(:buff_preset) { create(:buff_preset, name: "マッスルベアー", target_status: "strength", bonus_value: 12, duration_rounds: 3) }
  let(:valid_params) { { buff: { buff_preset_id: buff_preset.id } } }

  describe "GET /characters/:character_id/buffs/new" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get new_character_buff_path(character)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      it "正常にアクセスできる" do
        get new_character_buff_path(character)
        expect(response).to have_http_status(:ok)
      end

      it "フォームが表示される" do
        get new_character_buff_path(character)
        expect(response.body).to include("名前")
      end

      it "他ユーザーのキャラクターの場合404になる" do
        other_character = create(:character, user: create(:user))
        get new_character_buff_path(other_character)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /characters/:character_id/buffs（手動登録）" do
    let(:valid_manual_params) do
      { buff: { name: "陽光の魔符", target_status: "dexterity", bonus_value: 3, duration_rounds: 5 } }
    end
    let(:invalid_manual_params) do
      { buff: { name: "", target_status: "dexterity", bonus_value: 3, duration_rounds: 5 } }
    end

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        post character_buffs_path(character), params: valid_manual_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      context "有効なパラメータの場合" do
        it "バフが1件増える" do
          expect { post character_buffs_path(character), params: valid_manual_params }.to change(character.buffs, :count).by(1)
        end

        it "buff_preset_idはnilで、active/remaining_roundsが設定される" do
          post character_buffs_path(character), params: valid_manual_params
          buff = character.buffs.last
          expect(buff).to have_attributes(
            buff_preset_id: nil,
            name: "陽光の魔符",
            active: true,
            remaining_rounds: 5
          )
        end

        it "キャラクター詳細ページにリダイレクトされる" do
          post character_buffs_path(character), params: valid_manual_params
          expect(response).to redirect_to(character_path(character))
        end
      end

      context "無効なパラメータの場合（名前が空欄）" do
        it "バフが作成されない" do
          expect {
            post character_buffs_path(character), params: invalid_manual_params
          }.not_to change(Buff, :count)
        end

        it "422を返す" do
          post character_buffs_path(character), params: invalid_manual_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "認可チェック" do
        it "他ユーザーのキャラクターに対してPOSTした場合404になりバフが作成されない" do
          other_character = create(:character, user: create(:user))
          expect {
            post character_buffs_path(other_character), params: valid_manual_params
          }.not_to change(Buff, :count)
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

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

      context "プリセットが未選択（空文字）の場合" do
        it "バフが作成されずバリデーションエラーになる" do
          expect {
            post character_buffs_path(character), params: { buff: { buff_preset_id: "" } }
          }.not_to change(character.buffs, :count)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "エラーメッセージが表示される" do
          post character_buffs_path(character), params: { buff: { buff_preset_id: "" } }
          expect(response.body).to include("プリセットを選択してください")
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

  describe "GET /characters/:character_id/buffs/:id/edit" do
    let(:user_character) { create(:character, user: user) }
    let(:user_buff) { create(:buff, character: user_character, name: "陽光の魔符") }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get edit_character_buff_path(user_character, user_buff)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      it "正常なステータスコードが返る" do
        get edit_character_buff_path(user_character, user_buff)
        expect(response).to have_http_status(:ok)
      end

      it "正常に内容が表示される" do
        get edit_character_buff_path(user_character, user_buff)
        expect(response.body).to include("陽光の魔符")
      end

      it "他ユーザーのキャラクターの場合404になる" do
        other_character = create(:character, user: create(:user))
        other_buff = create(:buff, character: other_character)
        get edit_character_buff_path(other_character, other_buff)
        expect(response).to have_http_status(:not_found)
      end

      it "自分の別キャラクターに紐づくバフIDを指定した場合404になる" do
        another_character = create(:character, user: user)
        get edit_character_buff_path(another_character, user_buff)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /characters/:character_id/buffs/:id" do
    let(:character) { create(:character, user: user) }
    let(:buff) { create(:buff, character: character, name: "陽光の魔符", bonus_value: 3, duration_rounds: 5) }
    let(:valid_params) do
      { buff: { name: "陽光の魔符（強）", target_status: "dexterity", bonus_value: 10, duration_rounds: 3 } }
    end
    let(:invalid_params) do
      { buff: { name: "", target_status: "dexterity", bonus_value: 10, duration_rounds: 3 } }
    end

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        patch character_buff_path(character, buff), params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      context "有効なパラメータの場合" do
        it "有効なパラメータで更新される" do
          patch character_buff_path(character, buff), params: valid_params
          expect(response).to have_http_status(:found)
        end

        it "バフの内容が更新される" do
          expect {
            patch character_buff_path(character, buff), params: valid_params
          }.to change { buff.reload.name }.to("陽光の魔符（強）")
        end

        it "更新後メッセージが表示される" do
          patch character_buff_path(character, buff), params: valid_params
          expect(flash[:notice]).to eq("バフを更新しました")
        end

        it "更新後キャラクター詳細ページにリダイレクトされる" do
          patch character_buff_path(character, buff), params: valid_params
          expect(response).to redirect_to(character_path(character))
        end

        it "duration_roundsの変更に合わせてremaining_roundsも再同期される" do
          buff.update!(remaining_rounds: 1)
          patch character_buff_path(character, buff), params: valid_params
          expect(buff.reload.remaining_rounds).to eq(3)
        end
      end

      context "プリセット由来バフの場合" do
        let(:buff_preset) { create(:buff_preset, name: "マッスルベアー", target_status: "strength", bonus_value: 12) }
        let(:preset_buff) { create(:buff, :from_preset, character: character, buff_preset: buff_preset, bonus_value: 12) }
        let(:preset_valid_params) do
          { buff: { target_status: "strength", bonus_value: 20, duration_rounds: 3 } }
        end

        it "nameパラメータがなくてもbuff_presetの名前で表示され続ける" do
          patch character_buff_path(character, preset_buff), params: preset_valid_params
          expect(preset_buff.reload.display_name).to eq("マッスルベアー")
        end

        it "name以外の項目は更新される" do
          patch character_buff_path(character, preset_buff), params: preset_valid_params
          expect(preset_buff.reload.bonus_value).to eq(20)
        end
      end

      context "無効なパラメータの場合（名前が空欄）" do
        it "無効なパラメータで更新されない" do
          patch character_buff_path(character, buff), params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "更新できない場合エラーメッセージが表示される" do
          patch character_buff_path(character, buff), params: invalid_params
          expect(response.body).to include("Name can&#39;t be blank")
        end

        it "更新出来ない場合、DBの値が変わっていない" do
          expect {
            patch character_buff_path(character, buff), params: invalid_params
          }.not_to change { buff.reload.name }
        end
      end

      context "認可チェック" do
        it "他のユーザーのバフを編集できない" do
          other_character = create(:character, user: create(:user))
          other_buff = create(:buff, character: other_character)
          patch character_buff_path(other_character, other_buff), params: valid_params
          expect(response).to have_http_status(:not_found)
        end

        it "自分の別キャラクターに紐づくバフIDを指定した場合編集できない" do
          another_character = create(:character, user: user)
          patch character_buff_path(another_character, buff), params: valid_params
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
