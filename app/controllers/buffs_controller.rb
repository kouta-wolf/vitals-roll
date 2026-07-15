class BuffsController < ApplicationController
  before_action :set_character
  before_action :set_buff, only: [ :edit, :update ]

  def new
    @buff = Buff.new(character: @character)
    @buff_presets = BuffPreset.all
  end

  def create
    if buff_params.key?(:buff_preset_id)
      create_from_buff_preset
    else
      create_buff_manual
    end
  end

  def edit
  end

  def update
    attrs = manual_buff_params.merge(remaining_rounds: manual_buff_params[:duration_rounds])

    if @buff.update(attrs)
      redirect_to character_path(@character), notice: "バフを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def create_from_buff_preset
    # 空文字のままBuffPreset.findに渡すとRecordNotFoundで404へ渡される。
    # new.htmlと同じ表示にするため@buff/@buff_presetsもnewアクションと同様にセット。
    if buff_params[:buff_preset_id].blank?
      @buff = Buff.new(character: @character)
      @buff_presets = BuffPreset.all
      @preset_error = "プリセットを選択してください"
      return render :new, status: :unprocessable_entity
    end

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

  def create_buff_manual
    @buff = Buff.new(manual_buff_params.merge(character: @character))
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

  def set_buff
    @buff = @character.buffs.find(params[:id])
  end

  def buff_params
    params.require(:buff).permit(:buff_preset_id, :name, :target_status, :bonus_value, :duration_rounds)
  end

  def manual_buff_params
    buff_params.except(:buff_preset_id)
  end
end
