class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # ページ全てをログイン必須にする（Deviseのログイン/新規登録等は除外）
  before_action :authenticate_user!, unless: :devise_controller?

  # ログイン後はキャラクター一覧へ遷移する
  def after_sign_in_path_for(_resource)
    characters_path
  end
end
