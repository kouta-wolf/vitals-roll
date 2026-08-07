class BuffsController < ApplicationController
  before_action :set_character
  before_action :preload_buffs_with_preset, only: :toggle
  before_action :set_buff, only: [ :edit, :update, :destroy, :toggle ]

  def new
    # @character.buffs.newだと未保存レコードがcharacter.buffsの内部配列に混入し、
    # 同一リクエスト内でrender character.buffsした際に一覧へ紛れ込むため使わない
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
    if @buff.update(resynced_attrs)
      redirect_to character_path(@character), notice: "バフを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @buff.destroy
    redirect_to character_path(@character), notice: "バフを削除しました"
  end

  def toggle
    @buff.toggle_active!
    @weapons = @character.weapons
    @selected_weapon = @weapons.find_by(id: params[:weapon_id]) || @weapons.first

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to character_path(@character) }
    end
  end

  private

  def create_from_buff_preset
    # 空文字のままBuffPreset.findに渡すとRecordNotFoundで404へ渡される。
    # new.htmlと同じ表示にするため@buff/@buff_presetsもnewアクションと同様にセット。
    if buff_params[:buff_preset_id].blank?
      @buff = Buff.new(character: @character) # 理由はnewアクション参照
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
    @buff = Buff.new(manual_buff_params.merge(character: @character)) # 理由はnewアクション参照
    # 登録直後はactive: false。オンにした時だけ判定式へ反映される仕様のため、登録時点で式が黙って変わるのを防ぐ
    @buff.active = false
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

  def preload_buffs_with_preset
    @character.preload_buffs_with_preset!
  end

  # toggleでは直前にプリロードしているため、ここでのfindはSQLを投げずメモリ内走査になり
  # プリロード済み配列と同一インスタンスが返る(Character側のinverse_of指定による)
  def set_buff
    @buff = @character.buffs.find(params[:id])
  end

  def buff_params
    params.require(:buff).permit(:buff_preset_id, :name, :target_status, :bonus_value, :duration_rounds, :value_kind)
  end

  def manual_buff_params
    buff_params.except(:buff_preset_id)
  end

  # duration_rounds編集時は残りラウンドをリセットする仕様。
  # 更新後はactive: falseに落とす。オンにした時だけ判定式へ反映される仕様に揃え、更新時点で式が黙って変わるのを防ぐ
  def resynced_attrs
    manual_buff_params.merge(remaining_rounds: manual_buff_params[:duration_rounds], active: false)
  end
end
