class CharactersController < ApplicationController
  before_action :set_character, only: [ :show, :edit, :update, :destroy, :advance_round, :retreat_round, :reset_round ]

  def index
    @characters = current_user.characters.order(updated_at: :desc).page(params[:page]).per(8)
  end

  def new
    @character = current_user.characters.new
  end

  def create
    @character = current_user.characters.new(character_params)
    if @character.save
      redirect_to characters_path, notice: "キャラクターを作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @buff_presets = BuffPreset.all
    @weapons = @character.weapons
    @selected_weapon = @weapons.find_by(id: params[:weapon_id]) || @weapons.first
  end

  def edit
  end

  def update
    if @character.update(character_params)
      redirect_to @character, notice: "キャラクターを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @character.destroy
    redirect_to characters_path, notice: "キャラクターを削除しました"
  end

  def advance_round
    @character.advance_round!
    set_weapons_for_formula

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @character }
    end
  end

  def retreat_round
    @character.retreat_round!
    set_weapons_for_formula

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @character }
    end
  end

  def reset_round
    @character.reset_round!
    set_weapons_for_formula

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @character, notice: "ラウンドをリセットしました" }
    end
  end

  private

  def character_params
    params.require(:character).permit(:name, :race, :main_class, :main_class_level, :dexterity, :agility, :strength, :vitality, :intelligence, :spirit, :defense, :current_rounds)
  end

  def set_character
    @character = current_user.characters.find(params[:id])
  end

  def set_weapons_for_formula
    @weapons = @character.weapons
    @selected_weapon = @weapons.find_by(id: params[:weapon_id]) || @weapons.first
  end
end
