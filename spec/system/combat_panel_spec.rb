require "rails_helper"

# キャラクター詳細の戦闘操作を「ブラウザ → React → 保存 → DB」まで通しで検証する(#195)。
# reducer・保存フック（Vitest）と保存先（request spec）は個別にテストしているが、
# 両者をつなぐ経路（初期データの受け渡し、デバウンス保存、Turbo遷移の待ち合わせ）はここでしか検証できない。
RSpec.describe "戦闘操作", type: :system do
  let(:user) { create(:user) }
  # DEX 12 → ボーナス2、冒険者レベル3 → 命中 2d6+5+0
  let(:character) { create(:character, user: user) }
  # 威力25・C値10・固定値1 → ダメージ k25[10]+1
  let!(:weapon) { create(:weapon, character: character) }

  # デバウンス（2秒）を待ってから保存されるため、既定の待ち時間では足りない
  let(:save_wait) { 10 }

  before { sign_in user }

  def buff_checkbox(name)
    find("input[type=checkbox][aria-label='#{name}の有効/無効']")
  end

  def wait_until_saved
    expect(page).to have_css("#round-panel", text: "保存済み", wait: save_wait)
  end

  describe "バフのON/OFF" do
    let!(:buff) { create(:buff, character: character, name: "マッスルベアー", target_status: "strength", bonus_value: 2) }

    it "ONにすると判定式に反映され、リロードしても状態が残る" do
      visit character_path(character)
      expect(page).to have_css("#formula-panel", text: "k25[10]+1")

      buff_checkbox("マッスルベアー").check
      expect(page).to have_css("#formula-panel", text: "k25[10]+3")

      wait_until_saved
      expect(buff.reload.active).to be(true)

      visit character_path(character)
      expect(buff_checkbox("マッスルベアー")).to be_checked
      expect(page).to have_css("#formula-panel", text: "k25[10]+3")
    end
  end

  describe "ラウンド進行" do
    let!(:expiring_buff) do
      create(:buff, character: character, name: "キャッツアイ", target_status: "dexterity",
                    bonus_value: 1, duration_rounds: 1, remaining_rounds: 1, active: true)
    end
    let!(:endless_buff) do
      create(:buff, character: character, name: "剣の加護", target_status: "strength",
                    bonus_value: 1, duration_rounds: nil, remaining_rounds: nil, active: true)
    end

    it "残りラウンドが0になったバフは自動でOFFになり、判定式から外れる" do
      character.update!(current_rounds: 1)
      visit character_path(character)
      expect(page).to have_css("#formula-panel", text: "2d6+5+1")

      click_button "進める"

      expect(page).to have_css("#round-panel", text: "現在のラウンド: 2")
      expect(buff_checkbox("キャッツアイ")).not_to be_checked
      expect(page).to have_css("#formula-panel", text: "2d6+5+0")
      # 無限持続のバフはラウンド進行の影響を受けない
      expect(buff_checkbox("剣の加護")).to be_checked
      expect(page).to have_css("#buff-list-panel", text: "残り∞")

      wait_until_saved
      expect(character.reload.current_rounds).to eq(2)
      expect(expiring_buff.reload).to have_attributes(active: false, remaining_rounds: 0)
      expect(endless_buff.reload).to have_attributes(active: true, remaining_rounds: nil)
    end
  end

  describe "Turbo遷移と保存" do
    let!(:buff) { create(:buff, character: character, name: "マッスルベアー") }

    it "デバウンス待ちの間に別ページへ遷移しても、変更が保存されている" do
      visit character_path(character)

      buff_checkbox("マッスルベアー").check
      # デバウンス（2秒）を待たずに遷移する。turbo:before-fetch-request で保存を待ち合わせる
      click_link "キャラクター編集"

      expect(page).to have_current_path(edit_character_path(character))
      expect(buff.reload.active).to be(true)

      visit character_path(character)
      expect(buff_checkbox("マッスルベアー")).to be_checked
    end
  end
end
