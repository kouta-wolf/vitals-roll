class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # ページ全てをログイン必須にする（個別解除はskip_before_action)
  before_action :authenticate_user!
end
