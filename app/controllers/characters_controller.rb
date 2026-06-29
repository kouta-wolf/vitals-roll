class CharactersController < ApplicationController
  def index
    @characters = current_user.characters.page(params[:page]).per(8)
  end
end
