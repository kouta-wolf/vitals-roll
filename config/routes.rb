Rails.application.routes.draw do
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  devise_for :users
  root "top#index"

  resources :characters do
    resources :weapons, only: [ :new, :create, :edit, :update, :destroy ]
    resources :buffs, only: [ :new, :create, :edit, :update, :destroy ]

    # 戦闘中の状態をスナップショットでまとめて保存する（#159）。
    # POSTも受けるのは、離脱時のフラッシュに使う navigator.sendBeacon が
    # 常にPOSTで送るため。PATCH/PUTだけだとフラッシュが毎回404になる
    match "combat_state", to: "combat_states#update", via: [ :patch, :put, :post ], as: :combat_state
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
