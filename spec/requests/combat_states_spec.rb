require 'rails_helper'

RSpec.describe "CombatStates", type: :request do
  let(:user) { create(:user) }
  let(:character) { create(:character, user: user, current_rounds: 1) }
  let!(:buff) { create(:buff, character: character, active: false, remaining_rounds: 3, duration_rounds: 3) }
  let!(:other_buff) { create(:buff, character: character, active: true, remaining_rounds: 2, duration_rounds: 3) }

  let(:snapshot) do
    {
      current_rounds: 5,
      buffs: [
        { id: buff.id, active: true, remaining_rounds: 2 },
        { id: other_buff.id, active: false, remaining_rounds: 0 }
      ]
    }
  end

  def patch_snapshot(payload, target: character)
    patch character_combat_state_path(target), params: payload, as: :json
  end

  describe "PATCH /characters/:character_id/combat_state" do
    context "未ログインの場合" do
      # JSONリクエストに対して Devise はリダイレクトではなく401を返す。
      # クライアントは fetch / sendBeacon から呼ぶため、この方が扱いやすい
      it "401を返す" do
        patch_snapshot(snapshot)
        expect(response).to have_http_status(401)
      end

      it "状態が変わらない" do
        expect { patch_snapshot(snapshot) }.not_to change { character.reload.current_rounds }
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "204を返す（本文は使わない）" do
        patch_snapshot(snapshot)
        expect(response).to have_http_status(204)
        expect(response.body).to be_empty
      end

      it "current_roundsと複数バフをまとめて更新する" do
        patch_snapshot(snapshot)

        expect(character.reload.current_rounds).to eq(5)
        expect(buff.reload).to have_attributes(active: true, remaining_rounds: 2)
        expect(other_buff.reload).to have_attributes(active: false, remaining_rounds: 0)
      end

      # 差分ではなくスナップショットを送るため、遅延や順序入れ替わりがあっても
      # 最終結果が壊れないことを保証する
      it "同じスナップショットを2回送っても結果が変わらない（冪等）" do
        patch_snapshot(snapshot)
        first = [ character.reload.current_rounds, buff.reload.attributes, other_buff.reload.attributes ]

        patch_snapshot(snapshot)
        second = [ character.reload.current_rounds, buff.reload.attributes, other_buff.reload.attributes ]

        expect(second[0]).to eq(first[0])
        expect(second[1].except("updated_at")).to eq(first[1].except("updated_at"))
        expect(second[2].except("updated_at")).to eq(first[2].except("updated_at"))
      end

      it "無限バフ（remaining_rounds: nil）を維持できる" do
        infinite = create(:buff, character: character, active: true, duration_rounds: nil, remaining_rounds: nil)
        patch_snapshot({ current_rounds: 2, buffs: [ { id: infinite.id, active: true, remaining_rounds: nil } ] })

        expect(infinite.reload).to have_attributes(active: true, remaining_rounds: nil)
      end

      it "buffsを省略してもcurrent_roundsだけ更新できる" do
        patch_snapshot({ current_rounds: 9 })

        expect(character.reload.current_rounds).to eq(9)
        expect(buff.reload.active).to be(false)
      end

      context "認可チェック" do
        it "他ユーザーのキャラクターは404になり更新されない" do
          other_character = create(:character, user: create(:user), current_rounds: 1)

          expect { patch_snapshot({ current_rounds: 7 }, target: other_character) }
            .not_to change { other_character.reload.current_rounds }
          expect(response).to have_http_status(404)
        end

        it "存在しないキャラクターidは404になる" do
          patch character_combat_state_path(character_id: 0), params: { current_rounds: 1 }, as: :json
          expect(response).to have_http_status(404)
        end

        # 他キャラクターのバフIDが混ざっても、そのバフは対象外として無視される
        it "他キャラクターのバフIDを混入させても更新されない" do
          foreign_buff = create(:buff, character: create(:character, user: create(:user)), active: false, remaining_rounds: 3)

          expect {
            patch_snapshot({ current_rounds: 3, buffs: [ { id: foreign_buff.id, active: true, remaining_rounds: 0 } ] })
          }.not_to change { foreign_buff.reload.attributes.slice("active", "remaining_rounds") }

          expect(response).to have_http_status(204)
          expect(character.reload.current_rounds).to eq(3)
        end

        it "自分の別キャラクターのバフIDも更新されない" do
          sibling_buff = create(:buff, character: create(:character, user: user), active: false, remaining_rounds: 3)

          expect {
            patch_snapshot({ current_rounds: 3, buffs: [ { id: sibling_buff.id, active: true, remaining_rounds: 0 } ] })
          }.not_to change { sibling_buff.reload.attributes.slice("active", "remaining_rounds") }
        end
      end

      # sendBeacon はヘッダを付けられないため、CSRFトークンをJSONボディへ入れる必要がある。
      # #160 でここを間違えると保存が静かに422で失敗するため、実際に検証しておく。
      # test環境は既定でCSRF保護が無効なので、このcontextだけ有効化する
      context "CSRF保護が有効な場合" do
        around do |example|
          original = ActionController::Base.allow_forgery_protection
          ActionController::Base.allow_forgery_protection = true
          example.run
        ensure
          ActionController::Base.allow_forgery_protection = original
        end

        def csrf_token_from_page
          get character_path(character)
          Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
        end

        it "authenticity_tokenをJSONボディに含めれば更新できる" do
          token = csrf_token_from_page
          patch_snapshot(snapshot.merge(authenticity_token: token))

          expect(response).to have_http_status(204)
          expect(character.reload.current_rounds).to eq(5)
        end

        it "authenticity_tokenが無ければ弾かれ、状態も変わらない" do
          expect { patch_snapshot(snapshot) }.not_to change { character.reload.current_rounds }
          expect(response).not_to have_http_status(204)
        end
      end

      context "バリデーション違反の場合" do
        # remaining_rounds は 0..50
        let(:invalid_snapshot) do
          { current_rounds: 42, buffs: [ { id: buff.id, active: true, remaining_rounds: 999 } ] }
        end

        it "422を返す" do
          patch_snapshot(invalid_snapshot)
          expect(response).to have_http_status(422)
        end

        it "エラーメッセージを返す" do
          patch_snapshot(invalid_snapshot)
          expect(response.parsed_body["errors"]).to be_present
        end

        # キャラクターの更新のほうが先に走るため、ロールバックされないと
        # current_rounds だけ保存された中途半端な状態になる
        it "トランザクションがロールバックされ、current_roundsも保存されない" do
          expect { patch_snapshot(invalid_snapshot) }.not_to change { character.reload.current_rounds }
        end

        it "バフも保存されない" do
          expect { patch_snapshot(invalid_snapshot) }
            .not_to change { buff.reload.attributes.slice("active", "remaining_rounds") }
        end

        it "current_roundsが負の値なら422になる" do
          patch_snapshot({ current_rounds: -1 })
          expect(response).to have_http_status(422)
        end

        # activeはDBがNOT NULLなので、nilを許すとNotNullViolation(500)になる
        it "activeがnilなら500ではなく422になる" do
          patch_snapshot({ current_rounds: 2, buffs: [ { id: buff.id, active: nil, remaining_rounds: 1 } ] })
          expect(response).to have_http_status(422)
        end
      end
    end
  end
end
