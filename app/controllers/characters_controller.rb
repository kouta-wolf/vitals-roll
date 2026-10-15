class CharactersController < ApplicationController
  before_action :set_character, only: [ :show, :edit, :update, :destroy ]

  def index
    @characters = current_user.characters.order(updated_at: :desc).page(params[:page]).per(8)
  end

  def new
    @character = current_user.characters.new
    @character.weapons.build
  end

  def create
    @character = current_user.characters.new(character_create_params)
    if @character.save
      # 武器があれば判定式をすぐ使えるので詳細へ、無ければ従来どおり一覧へ戻す
      redirect_to (@character.weapons.any? ? @character : characters_path), notice: "キャラクターを作成しました"
    else
      @character.weapons.build if @character.weapons.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @buff_presets = BuffPreset.all
    @weapons = @character.weapons
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

  private

  def character_params
    params.require(:character).permit(:name, :race, :main_class, :main_class_level, :dexterity, :agility, :strength, :vitality, :intelligence, :spirit, :defense, :current_rounds)
  end

  # 武器の同時登録は新規作成のときだけ受け付ける。編集画面の武器は WeaponsController が扱う
  def character_create_params
    params.require(:character).permit(
      :name, :race, :main_class, :main_class_level, :dexterity, :agility, :strength, :vitality, :intelligence, :spirit, :defense,
      weapons_attributes: [ :name, :power, :critical, :fixed_value, :fixed_hit_rate ]
    )
  end

  def set_character
    @character = current_user.characters.find(params[:id])
  end
end
