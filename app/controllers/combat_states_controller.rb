# 戦闘中の状態（ラウンドと各バフのオン/オフ・残ラウンド）をまとめて保存する。
#
# 差分ではなく「現在の状態そのもの」をスナップショットとして受け取るため冪等であり、
# リクエストが遅延しても順序が入れ替わっても最終結果が壊れない。クライアント側は
# 操作のたびに送らず、変更をデバウンスしてまとめて送る想定（#160）。
#
# Content-Type は application/json のみを受け付ける。`navigator.sendBeacon` から
# 送る場合は Blob の type に application/json を指定し、CSRFトークンを
# `authenticity_token` としてJSONボディへ含めること。sendBeacon はヘッダを
# 付けられないため、text/plain で送るとRailsがボディを解析せず
# CSRF検証も通らなくなる（検証を外すのは状態変更エンドポイントとして不適切）。
class CombatStatesController < ApplicationController
  before_action :set_character

  def update
    ApplicationRecord.transaction do
      @character.update!(current_rounds: combat_state_params[:current_rounds])
      update_buffs!
    end

    head :no_content
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_character
    @character = current_user.characters.find(params[:character_id])
  end

  def combat_state_params
    params.permit(:current_rounds, buffs: [ :id, :active, :remaining_rounds ])
  end

  def update_buffs!
    requested = combat_state_params[:buffs]
    return if requested.blank?

    # そのキャラクターに属するバフだけを対象にする。他キャラクターのIDや、
    # 別タブで削除済みのIDが混ざっても単に対象外になるだけで、他人のデータは触らない
    buffs = @character.buffs.where(id: requested.map { |attrs| attrs[:id] }).index_by(&:id)

    requested.each do |attrs|
      buff = buffs[attrs[:id].to_i]
      next if buff.nil?

      buff.update!(active: attrs[:active], remaining_rounds: attrs[:remaining_rounds])
    end
  end
end
