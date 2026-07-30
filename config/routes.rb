Rails.application.routes.draw do
  devise_for :users
  root "top#index"

  resources :characters do
    resources :weapons, only: [ :new, :create, :edit, :update, :destroy ]
    resources :buffs, only: [ :new, :create, :edit, :update, :destroy ] do
      member do
        patch :toggle
      end
    end

    member do
      patch :advance_round
      patch :retreat_round
      patch :reset_round
    end
  end

  # 静的ページ
  controller :pages do
    get "terms", action: :terms
    get "privacy", action: :privacy
    # 現時点でgoogleフォームのためgetのみ
    get "contact", action: :contact
    get "guide", action: :guide
  end
  # Renderのヘルスチェック用（/up が200を返す）
  get "up" => "rails/health#show", as: :rails_health_check
end
