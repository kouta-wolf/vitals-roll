require "rails_helper"

# ログインからキャラクター作成、詳細表示までの導線(#195)
RSpec.describe "ログインからキャラクター作成まで", type: :system do
  # factory の既定値 "password" は漏洩パスワードの一覧に載っており、Google Chrome（CIのランナー）は
  # フォームからログインした直後に漏洩の警告を出す。警告がキー入力を奪い、以降の fill_in が
  # 空のまま送信されるため、漏洩していないパスワードを使う（Chromiumでは警告が出ず再現しない）
  let(:password) { "Vr-system-spec-7q2k" }
  let!(:user) { create(:user, email: "player@example.com", password: password, password_confirmation: password) }

  it "ログインしてキャラクターを作成すると、一覧から詳細を開ける" do
    visit new_user_session_path
    fill_in "メールアドレス", with: "player@example.com"
    fill_in "パスワード", with: password
    click_button "ログイン"

    expect(page).to have_current_path(characters_path)

    click_link "新規作成"
    fill_in "キャラクター名", with: "アルフォンス"
    abilities = %w[器用度（DEX） 敏捷度（AGI） 筋力（STR） 生命力（VIT） 知力（INT） 精神力（MND）]
    abilities.each { |label| fill_in label, with: 12 }
    # 入力が奪われた場合に「作成されない」ではなく「入力が残っていない」で落ちるようにする
    expect(page).to have_field("キャラクター名", with: "アルフォンス")
    abilities.each { |label| expect(page).to have_field(label, with: "12") }
    click_button "作成する"

    expect(page).to have_content("キャラクターを作成しました")
    click_link "アルフォンス"

    expect(page).to have_css("h1", text: "アルフォンス")
    # 武器が無いうちは判定式の代わりに案内を出す
    expect(page).to have_css("#formula-panel", text: "武器が登録されていません")
  end
end
