class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  def terms; end
  def privacy; end
  def contact; end
  def guide; end
end
