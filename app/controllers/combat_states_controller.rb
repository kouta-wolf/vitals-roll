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
  before_action :require_json_request
  before_action :set_character

  def update
    ApplicationRecord.transaction do
      update_current_rounds!
      update_buffs!
    end

    head :no_content
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue ActiveModel::RangeError
    # current_rounds には上限バリデーションを置いていない（理由は Character のコメント参照）
    # ため、PostgreSQLのinteger範囲を超える値はDB書き込み時に RangeError になる。
    # クライアントの生JSONを受けるエンドポイントなので、500にせず422で返す
    render json: { errors: [ "数値が扱える範囲を超えています" ] }, status: :unprocessable_entity
  end

  private

  # ボディの解析とCSRF検証を成立させるための前提。コメントで宣言するだけでなく実際に弾く
  def require_json_request
    head :unsupported_media_type unless request.media_type == "application/json"
  end

  def set_character
    @character = current_user.characters.find(params[:character_id])
  end

  def combat_state_params
    @combat_state_params ||= params.permit(:current_rounds, buffs: [ :id, :active, :remaining_rounds ])
  end

  # キーが無い場合は触らない。無条件に代入すると、バフだけを含むスナップショットで
  # current_rounds が nil になり、presence バリデーションでトランザクション全体が
  # ロールバックして、送られてきたバフの変更まで失われる
  def update_current_rounds!
    return unless combat_state_params.key?(:current_rounds)

    @character.update!(current_rounds: combat_state_params[:current_rounds])
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

      # 送られてきたキーだけを更新する。remaining_rounds を無条件に代入すると、
      # 省略された場合に nil（＝無限持続）になり、持続3ラウンドのバフが永続バフへ
      # 静かに化けて以降一切減算されなくなる
      buff.update!(attrs.slice(:active, :remaining_rounds))
    end
  end
end
