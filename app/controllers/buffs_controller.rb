class BuffsController < ApplicationController
  before_action :set_character

  def new
    @buff = @character.buffs.new
    @buff_presets = BuffPreset.all
  end

  def create
    if buff_params.key?(:buff_preset_id)
      create_from_preset
    else
      create_manual
    end
  end

  private

  def create_from_preset
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

  def create_manual
    @buff = @character.buffs.new(manual_buff_params)
    @buff.active = true
    @buff.remaining_rounds = @buff.duration_rounds

    if @buff.save
      redirect_to character_path(@character), notice: "バフを作成しました"
    else
      @buff_presets = BuffPreset.all
      render :new, status: :unprocessable_entity
    end
  end

  def set_character
    @character = current_user.characters.find(params[:character_id])
  end

  def buff_params
    params.require(:buff).permit(:buff_preset_id, :name, :target_status, :bonus_value, :duration_rounds)
  end

  def manual_buff_params
    buff_params.except(:buff_preset_id)
  end
end
