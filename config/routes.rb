Rails.application.routes.draw do
  root "top#index"

  # Renderのヘルスチェック用（/up が200を返す）
  get "up" => "rails/health#show", as: :rails_health_check
end
