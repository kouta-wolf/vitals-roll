class WeaponsController < ApplicationController
  def new
    @character = current_user.characters.find(params[:character_id])
    @weapon = @character.weapons.new
  end

  def create
    @character = current_user.characters.find(params[:character_id])
    @weapon = @character.weapons.new(weapon_params)
    if @weapon.save
      redirect_to edit_character_path(@character), notice: "武器を作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def weapon_params
    params.require(:weapon).permit(:name, :power, :critical, :fixed_value, :fixed_hit_rate)
  end
end
