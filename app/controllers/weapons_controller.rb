class WeaponsController < ApplicationController
  before_action :set_character
  before_action :set_weapon, only: [ :edit, :update, :destroy ]

  def new
    @weapon = @character.weapons.new
  end

  def create
    @weapon = @character.weapons.new(weapon_params)
    if @weapon.save
      redirect_to edit_character_path(@character), notice: "武器を作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @weapon.update(weapon_params)
      redirect_to edit_character_path(@character), notice: "武器を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @weapon.destroy
    redirect_to edit_character_path(@character), notice: "武器を削除しました"
  end

  private

  def set_character
    @character = current_user.characters.find(params[:character_id])
  end

  def set_weapon
    @weapon = @character.weapons.find(params[:id])
  end

  def weapon_params
    params.require(:weapon).permit(:name, :power, :critical, :fixed_value, :fixed_hit_rate)
  end
end
