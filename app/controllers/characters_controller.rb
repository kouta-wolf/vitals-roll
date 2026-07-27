class CharactersController < ApplicationController
  before_action :set_character, only: [ :show, :edit, :update, :destroy, :advance_round, :retreat_round, :reset_round, :hit_formula, :attack_formula ]
  before_action :set_weapon, only: [ :hit_formula, :attack_formula ]

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

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @character }
    end
  end

  def retreat_round
    @character.retreat_round!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @character }
    end
  end

  def reset_round
    @character.reset_round!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @character, notice: "ラウンドをリセットしました" }
    end
  end

  def hit_formula
    @formula = @character.hit_formula(@weapon)
  end

  def attack_formula
    @formula = @character.attack_formula(@weapon)
  end

  private

  def character_params
    params.require(:character).permit(:name, :race, :main_class, :main_class_level, :dexterity, :agility, :strength, :vitality, :intelligence, :spirit, :defense, :current_rounds)
  end

  def set_character
    @character = current_user.characters.find(params[:id])
  end

  def set_weapon
    @weapon = @character.weapons.find(params[:weapon_id])
  end
end
