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
      before { sign_in user }

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

      it "基礎ステータス6種と防護点が表示される" do
        get character_path(user_character)
        expect(response.body).to include("器用度（DEX）: 12")
        expect(response.body).to include("敏捷度（AGI）: 12")
        expect(response.body).to include("筋力（STR）: 12")
        expect(response.body).to include("生命力（VIT）: 12")
        expect(response.body).to include("知力（INT）: 12")
        expect(response.body).to include("精神力（MND）: 12")
        expect(response.body).to include("防護点: 4")
      end
    end
  end

  describe "GET /characters/:id/edit" do
    let(:user_character) { create(:character, user: user) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        get edit_character_path(user_character)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      it "正常にアクセスできる" do
        get edit_character_path(user_character)
        expect(response).to have_http_status(200)
      end

      it "正常に内容が表示される" do
        get edit_character_path(user_character)
        expect(response.body).to include("テスター・ドラゴン")
        expect(response.body).to include("テストドレイク")
      end

      it "他のユーザーのキャラを閲覧できない" do
        other_user = create(:user)
        other_character = create(:character, user: other_user, name: "ヨソ・キャラ")
        get edit_character_path(other_character)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "PATCH /characters/:id" do
    let(:user_character) { create(:character, user: user) }
    let(:valid_params) do
      {
        character: {
          name: "アルテスト", race: "ヒューマン", main_class: "フェンサー", main_class_level: 3,
          dexterity: 12, agility: 10, strength: 14,
          vitality: 11, intelligence: 8, spirit: 9, defense: 4
        }
      }
    end

    let(:invalid_params) do
      {
        character: {
          name: "", race: "", main_class: "", main_class_level: 3,
          dexterity: 12, agility: 10, strength: 14,
          vitality: 11, intelligence: 8, spirit: 9, defense: 4
        }
      }
    end

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        patch character_path(user_character), params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済の場合" do
      before { sign_in user }

      context "有効なパラメータの場合" do
        it "有効なパラメータで更新できる" do
          patch character_path(user_character), params: valid_params
          expect(response).to have_http_status(302)
        end

        it "キャラクターの内容が更新される" do
          expect {
            patch character_path(user_character), params: valid_params
          }.to change { user_character.reload.name }.to("アルテスト")
        end


        it "更新後メッセージが表示される" do
          patch character_path(user_character), params: valid_params
          expect(flash[:notice]).to eq("キャラクターを更新しました")
        end

        it "更新後詳細ページへリダイレクトされる" do
          patch character_path(user_character), params: valid_params
          expect(response).to redirect_to(character_path(user_character))
        end
      end

      context "無効なパラメータの場合" do
        it "無効なパラメータで更新されない" do
          patch character_path(user_character), params: invalid_params
          expect(response).to have_http_status(422)
        end

        it "更新できない場合エラーメッセージが表示される" do
          patch character_path(user_character), params: invalid_params
          expect(response.body).to include("入力に誤りがあります")
        end

        it "更新出来ない場合、DBの値が変わっていない" do
          expect { patch character_path(user_character), params: invalid_params }.not_to change { user_character.reload.name }
        end
      end

      context "認可チェック" do
        it "他のユーザーのキャラクターを編集できない" do
          other_user = create(:user)
          other_character = create(:character, user: other_user, name: "ヨソ・キャラ")
          patch character_path(other_character), params: valid_params
          expect(response).to have_http_status(404)
        end
      end
    end
  end

  describe "DELETE /characters/:id" do
    let!(:user_character) { create(:character, user: user) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        delete character_path(user_character)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "正常に削除できる(レコードが1件減る)" do
        expect { delete character_path(user_character) }.to change(user.characters, :count).by(-1)
      end

      it "削除後のメッセージが表示される" do
        delete character_path(user_character)
        expect(flash[:notice]).to eq("キャラクターを削除しました")
      end

      it "削除した後に削除キャラが表示されていないか" do
        delete character_path(user_character)
        follow_redirect!
        expect(response.body).not_to include("テスター・ドラゴン")
      end

      context "認可チェック" do
        it "他のユーザーのキャラクターを削除できない" do
          other_user = create(:user)
          other_character = create(:character, user: other_user, name: "ヨソ・キャラ")
          expect { delete character_path(other_character) }.not_to change(Character, :count)
          expect(response).to have_http_status(404)
        end
      end
    end
  end

  describe "PATCH /characters/:id/advance_round" do
    let(:user_character) { create(:character, user: user, current_rounds: 2) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        patch advance_round_character_path(user_character)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "current_roundsが1増える" do
        expect {
          patch advance_round_character_path(user_character)
        }.to change { user_character.reload.current_rounds }.from(2).to(3)
      end

      it "activeなバフのremaining_roundsが1減る" do
        buff = create(:buff, character: user_character, active: true, duration_rounds: 3, remaining_rounds: 3)
        patch advance_round_character_path(user_character)
        expect(buff.reload.remaining_rounds).to eq(2)
      end

      it "remaining_roundsが0になったバフはactive: falseになる" do
        buff = create(:buff, character: user_character, active: true, duration_rounds: 3, remaining_rounds: 1)
        patch advance_round_character_path(user_character)
        expect(buff.reload.active).to be false
      end

      it "turbo_stream形式でリクエストすると200が返る" do
        patch advance_round_character_path(user_character), as: :turbo_stream
        expect(response).to have_http_status(200)
        expect(response.media_type).to eq(Mime[:turbo_stream])
      end

      it "turbo_stream形式でリクエストするとバフ一覧の残りラウンドが更新される" do
        create(:buff, character: user_character, active: true, name: "テストバフ", duration_rounds: 3, remaining_rounds: 3)
        patch advance_round_character_path(user_character), as: :turbo_stream
        expect(response.body).to include("残り2R")
      end
    end

    context "認可チェック" do
      before { sign_in user }

      it "自分の別キャラクターのcurrent_roundsは変わらない" do
        another_character = create(:character, user: user, current_rounds: 2)
        expect {
          patch advance_round_character_path(user_character)
        }.not_to change { another_character.reload.current_rounds }
      end

      it "他ユーザーのキャラクターの場合404になりcurrent_roundsが変わらない" do
        other_user = create(:user)
        other_character = create(:character, user: other_user, current_rounds: 2)
        expect {
          patch advance_round_character_path(other_character)
        }.not_to change { other_character.reload.current_rounds }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /characters/:id/retreat_round" do
    let(:user_character) { create(:character, user: user, current_rounds: 2) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        patch retreat_round_character_path(user_character)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "current_roundsが1減る" do
        expect {
          patch retreat_round_character_path(user_character)
        }.to change { user_character.reload.current_rounds }.from(2).to(1)
      end

      it "current_roundsが0のときは0未満にならない" do
        zero_round_character = create(:character, user: user, current_rounds: 0)
        expect {
          patch retreat_round_character_path(zero_round_character)
        }.not_to change { zero_round_character.reload.current_rounds }
      end

      it "activeなバフのremaining_roundsが1増える" do
        buff = create(:buff, character: user_character, active: true, duration_rounds: 3, remaining_rounds: 1)
        patch retreat_round_character_path(user_character)
        expect(buff.reload.remaining_rounds).to eq(2)
      end

      it "remaining_roundsがduration_roundsに達していればそれ以上増えない" do
        buff = create(:buff, character: user_character, active: true, duration_rounds: 3, remaining_rounds: 3)
        patch retreat_round_character_path(user_character)
        expect(buff.reload.remaining_rounds).to eq(3)
      end

      it "turbo_stream形式でリクエストすると200が返る" do
        patch retreat_round_character_path(user_character), as: :turbo_stream
        expect(response).to have_http_status(200)
        expect(response.media_type).to eq(Mime[:turbo_stream])
      end

      it "turbo_stream形式でリクエストするとバフ一覧の残りラウンドが更新される" do
        create(:buff, character: user_character, active: true, name: "テストバフ", duration_rounds: 3, remaining_rounds: 1)
        patch retreat_round_character_path(user_character), as: :turbo_stream
        expect(response.body).to include("残り2R")
      end
    end

    context "認可チェック" do
      before { sign_in user }

      it "自分の別キャラクターのcurrent_roundsは変わらない" do
        another_character = create(:character, user: user, current_rounds: 2)
        expect {
          patch retreat_round_character_path(user_character)
        }.not_to change { another_character.reload.current_rounds }
      end

      it "他ユーザーのキャラクターの場合404になりcurrent_roundsが変わらない" do
        other_user = create(:user)
        other_character = create(:character, user: other_user, current_rounds: 2)
        expect {
          patch retreat_round_character_path(other_character)
        }.not_to change { other_character.reload.current_rounds }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /characters/:id/reset_round" do
    let(:user_character) { create(:character, user: user, current_rounds: 5) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        patch reset_round_character_path(user_character)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "current_roundsが0に戻る" do
        expect {
          patch reset_round_character_path(user_character)
        }.to change { user_character.reload.current_rounds }.from(5).to(0)
      end

      it "持続バフのremaining_roundsがduration_roundsに戻る" do
        buff = create(:buff, character: user_character, active: true, duration_rounds: 3, remaining_rounds: 1)
        patch reset_round_character_path(user_character)
        expect(buff.reload.remaining_rounds).to eq(3)
      end

      it "持続バフがactive: falseになる" do
        buff = create(:buff, character: user_character, active: true, duration_rounds: 3, remaining_rounds: 1)
        patch reset_round_character_path(user_character)
        expect(buff.reload.active).to be false
      end

      it "無限バフは変化しない" do
        buff = create(:buff, character: user_character, active: true, duration_rounds: nil, remaining_rounds: nil)
        patch reset_round_character_path(user_character)
        buff.reload
        expect(buff.active).to be true
        expect(buff.remaining_rounds).to be_nil
      end

      it "リセット後詳細ページへリダイレクトされる" do
        patch reset_round_character_path(user_character)
        expect(response).to redirect_to(character_path(user_character))
      end

      it "リセットしたことを明示するメッセージが表示される" do
        patch reset_round_character_path(user_character)
        expect(flash[:notice]).to eq("ラウンドをリセットしました")
      end
    end

    context "認可チェック" do
      before { sign_in user }

      it "自分の別キャラクターのcurrent_roundsは変わらない" do
        another_character = create(:character, user: user, current_rounds: 5)
        expect {
          patch reset_round_character_path(user_character)
        }.not_to change { another_character.reload.current_rounds }
      end

      it "自分の別キャラクターのバフは変わらない" do
        another_character = create(:character, user: user, current_rounds: 5)
        another_buff = create(:buff, character: another_character, active: true, duration_rounds: 3, remaining_rounds: 1)
        patch reset_round_character_path(user_character)
        expect(another_buff.reload.remaining_rounds).to eq(1)
      end

      it "他ユーザーのキャラクターの場合404になりcurrent_roundsが変わらない" do
        other_user = create(:user)
        other_character = create(:character, user: other_user, current_rounds: 5)
        expect {
          patch reset_round_character_path(other_character)
        }.not_to change { other_character.reload.current_rounds }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /characters/:id?weapon_id=" do
    let(:user_character) { create(:character, user: user, main_class_level: 3, dexterity: 12) }
    let!(:weapon_a) { create(:weapon, character: user_character, name: "武器A", power: 25, critical: 10, fixed_value: 1, fixed_hit_rate: 0) }
    let!(:weapon_b) { create(:weapon, character: user_character, name: "武器B", power: 15, critical: 9, fixed_value: 2, fixed_hit_rate: -1) }

    context "ログイン済みの場合" do
      before { sign_in user }

      it "weapon_id未指定の場合は先頭の武器の判定式が表示される" do
        get character_path(user_character)
        expect(response.body).to include("2d6+5+0")
        expect(response.body).to include("k25[10]+1")
      end

      it "weapon_idを指定するとその武器の判定式が表示される" do
        get character_path(user_character), params: { weapon_id: weapon_b.id }
        expect(response.body).to include("2d6+4+0")
        expect(response.body).to include("k15[9]+2")
      end

      it "武器が登録されていない場合はその旨のメッセージが表示される" do
        no_weapon_character = create(:character, user: user)
        get character_path(no_weapon_character)
        expect(response.body).to include("武器が登録されていません")
      end

      it "命中判定式・ダメージ判定式それぞれにコピーボタンが表示される" do
        get character_path(user_character)
        expect(response.body.scan('data-controller="clipboard"').count).to eq(2)
        expect(response.body.scan(/data-clipboard-target="button"[^>]*>\s*コピー\s*</).count).to eq(2)
      end

      it "コピー対象のテキストとして判定式が設定される" do
        get character_path(user_character)
        expect(response.body).to include('data-clipboard-target="source">2d6+5+0<')
        expect(response.body).to include('data-clipboard-target="source">k25[10]+1<')
      end
    end
  end
end
