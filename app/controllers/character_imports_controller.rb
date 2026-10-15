# ゆとシートⅡのJSONを読み込み、新規作成フォームへ値を入れて表示する(#194)。保存はしない
class CharacterImportsController < ApplicationController
  def create
    @import = YtsheetImport.new(json: params.dig(:ytsheet_import, :json))

    if @import.valid?
      @character = current_user.characters.new(@import.character_attributes)
      @character.weapons.build(@import.weapon_attributes || {})
      flash.now[:notice] = import_notice
      # 読み込みに成功したら貼り付け欄は空に戻す
      @import = YtsheetImport.new
      render "characters/new"
    else
      @character = current_user.characters.new
      @character.weapons.build
      render "characters/new", status: :unprocessable_entity
    end
  end

  private

  def import_notice
    message = "ゆとシートⅡから読み込みました。内容を確認して「作成する」を押してください"
    return message if @import.skipped_weapon_count.zero?

    "#{message}（武器は1本目のみ読み込みました。残り#{@import.skipped_weapon_count}本は作成後に編集画面から追加できます）"
  end
end
