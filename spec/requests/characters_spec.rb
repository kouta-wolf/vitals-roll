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

      it "空状態では使い方ガイドへのリンクが表示される" do
        get characters_path
        expect(response.body).to include(%(href="#{guide_path}"))
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

      it "レベルと防護点にDBのカラムデフォルトが入っている" do
        get new_character_path
        html = Nokogiri::HTML(response.body)
        expect(html.at_css("#character_main_class_level")["value"]).to eq("1")
        expect(html.at_css("#character_defense")["value"]).to eq("0")
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

      # ラウンド管理・バフ一覧・判定式はReactが描画する（#160）。
      # サーバ側の責務は「Reactが起動できる初期データを埋め込む」ことだけ
      context "Reactの初期データ" do
        let!(:weapon) { create(:weapon, character: user_character, name: "テストソード") }
        let!(:buff) { create(:buff, character: user_character, name: "自作バフ", active: true, remaining_rounds: 2) }

        def combat_state
          get character_path(user_character)
          node = Nokogiri::HTML(response.body).at_css("[data-react-root]")
          JSON.parse(node["data-combat-state"])
        end

        it "Reactのマウント先と各パネルの描画先が存在する" do
          get character_path(user_character)
          html = Nokogiri::HTML(response.body)

          expect(html.at_css("[data-react-root]")).to be_present
          expect(html.at_css("#round-panel")).to be_present
          expect(html.at_css("#buff-list-panel")).to be_present
          expect(html.at_css("#formula-panel")).to be_present
        end

        it "キャラクターのステータスと現在ラウンドを含む" do
          data = combat_state

          expect(data["character"]).to include("mainClassLevel" => 3, "dexterity" => 12, "currentRounds" => 1)
        end

        it "武器を含む" do
          expect(combat_state["weapons"]).to contain_exactly(
            hash_including("id" => weapon.id, "name" => "テストソード", "power" => 25, "critical" => 10)
          )
        end

        it "バフを含む" do
          expect(combat_state["buffs"]).to contain_exactly(
            hash_including("id" => buff.id, "name" => "自作バフ", "active" => true, "remainingRounds" => 2)
          )
        end

        it "プリセット由来バフはspecialTypeまで含む" do
          preset = create(:buff_preset, :special, name: "クリティカルレイ", bonus_value: 1)
          create(:buff, :from_preset, character: user_character, buff_preset: preset, target_status: nil)

          preset_data = combat_state["buffs"].find { |b| b["buffPreset"].present? }
          expect(preset_data["buffPreset"]).to include("name" => "クリティカルレイ", "specialType" => "critical_ray")
        end

        it "保存先URLとCSRFトークンを含む" do
          data = combat_state

          expect(data["saveUrl"]).to eq(character_combat_state_path(user_character))
          expect(data["csrfToken"]).to be_present
        end

        it "バフCRUDのパスを含む" do
          expect(combat_state["buffPathPrefix"]).to eq(character_buffs_path(user_character))
        end

        # バフ件数が増えてもbuff_presetのクエリが増えないこと
        it "バフのbuff_presetを引く際にN+1が発生しない" do
          3.times do
            preset = create(:buff_preset)
            create(:buff, :from_preset, character: user_character, buff_preset: preset)
          end

          queries = []
          subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
            queries << payload[:sql] if payload[:sql].include?("buff_presets")
          end

          get character_path(user_character)
          ActiveSupport::Notifications.unsubscribe(subscriber)

          # プリセット一覧用の1本と、includesでまとめて引く1本のみ
          expect(queries.size).to be <= 2
        end
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

      # フォームに value: をハードコードすると保存済みの値が初期値で上書きされるため、
      # 新規作成時の初期値と異なる値で反映を検証する
      it "保存済みのレベルと防護点がフォームに反映される" do
        get edit_character_path(user_character)
        html = Nokogiri::HTML(response.body)
        expect(html.at_css("#character_main_class_level")["value"]).to eq("3")
        expect(html.at_css("#character_defense")["value"]).to eq("4")
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

        # フォームの数値入力を空欄で送ると Rails が "" を nil にキャストする。
        # 以前はバリデーションが無く NULL が保存され、main_class_level が nil になると
        # hit_formula が NoMethodError で落ちて詳細ページが500になっていた（#168）
        context "レベル・防護点が空欄で送信された場合" do
          let(:blank_level_params) { { character: valid_params[:character].merge(main_class_level: "") } }
          let(:blank_defense_params) { { character: valid_params[:character].merge(defense: "") } }

          it "レベルが空欄なら422になり保存されない" do
            expect { patch character_path(user_character), params: blank_level_params }
              .not_to change { user_character.reload.main_class_level }
            expect(response).to have_http_status(422)
          end

          it "防護点が空欄なら422になり保存されない" do
            expect { patch character_path(user_character), params: blank_defense_params }
              .not_to change { user_character.reload.defense }
            expect(response).to have_http_status(422)
          end
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
end
