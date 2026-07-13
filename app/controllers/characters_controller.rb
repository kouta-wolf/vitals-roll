class CharactersController < ApplicationController
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
    @character = current_user.characters.find(params[:id])
    @buff_presets = BuffPreset.all
  end

  def edit
    @character = current_user.characters.find(params[:id])
  end

  def update
    @character = current_user.characters.find(params[:id])
    if @character.update(character_params)
      redirect_to @character, notice: "キャラクターを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @character = current_user.characters.find(params[:id])
    @character.destroy
    redirect_to characters_path, notice: "キャラクターを削除しました"
  end

  private

  def character_params
    params.require(:character).permit(:name, :race, :main_class, :main_class_level, :dexterity, :agility, :strength, :vitality, :intelligence, :spirit, :defense, :current_rounds)
  end
end
