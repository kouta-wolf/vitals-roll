require 'rails_helper'

RSpec.describe "Pages", type: :request do
  describe "GET /terms" do
    it "正常にアクセスできるか" do
      get terms_path
      expect(response).to have_http_status(200)
    end
  end

  describe "GET /privacy" do
    it "正常にアクセスできるか" do
      get privacy_path
      expect(response).to have_http_status(200)
    end
  end
end
