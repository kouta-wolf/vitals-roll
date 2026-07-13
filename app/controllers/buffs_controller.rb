class BuffsController < ApplicationController
  before_action :set_character

  def create
    buff_preset = BuffPreset.find(buff_params[:buff_preset_id])
    @buff = buff_preset.build_buff_for(@character)

    if @buff.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @character, notice: "バフを登録しました" }
      end
    else
      redirect_to @character, alert: @buff.errors.full_messages.to_sentence
    end
  end

  private

  def set_character
    @character = current_user.characters.find(params[:character_id])
  end

  def buff_params
    params.require(:buff).permit(:buff_preset_id)
  end
end
