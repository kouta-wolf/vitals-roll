Rails.application.routes.draw do
  devise_for :users
  root "top#index"

  # 静的ページ
  controller :pages do
    get "terms", action: :terms
    get "privacy", action: :privacy
    # 現時点でgoogleフォームのためgetのみ
    get "contact", action: :contact
  end
  # Renderのヘルスチェック用（/up が200を返す）
  get "up" => "rails/health#show", as: :rails_health_check
end
