require 'rails_helper'

RSpec.describe "Top", type: :request do
  describe "GET /" do
    it "正常にアクセスできるか" do
      get root_path
      expect(response).to have_http_status(200)
    end
  end
end
