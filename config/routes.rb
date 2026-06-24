Rails.application.routes.draw do
  root "top#index"

  # 静的ページ
  controller :pages do
    get "terms", action: :terms
    get "privacy", action: :privacy
  end
  # Renderのヘルスチェック用（/up が200を返す）
  get "up" => "rails/health#show", as: :rails_health_check
end
