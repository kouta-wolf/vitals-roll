require 'rails_helper'

RSpec.describe Character, type: :model do
  describe "アソシエーション" do
    it "userが無効なら無効となるか" do
      expect(build(:character, user: nil)).to be_invalid
    end
  end
end
