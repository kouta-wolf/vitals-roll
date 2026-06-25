require 'rails_helper'

RSpec.describe User, type: :model do
  it "有効なファクトリを持つ" do
    expect(build(:user)).to be_valid
  end

  describe "Email" do
    context "必須項目" do
      it "空文字なら無効" do
        user = build(:user, email: "")
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end
    end

    context "一意性" do
      it "同じメールアドレスが存在するなら無効" do
        create(:user, email: "user@example.com")
        user = build(:user, email: "user@example.com")
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end

      it "大文字小文字を区別せず無効になる" do
        create(:user, email: "USER@example.com")
        user = build(:user, email: "user@example.com")
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end
    end

    context "形式" do
      it "不正形式は無効になる" do
        user = build(:user, email: "user")
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end
    end
  end

  describe "Password" do
    context "必須項目" do
      it "空文字なら無効" do
        user = build(:user, password: "")
        expect(user).to be_invalid
        expect(user.errors[:password]).to be_present
      end
    end

    context "確認用不一致" do
      it "password_confirmationと一致しない場合は無効" do
        user = build(:user, password: "password", password_confirmation: "different")
        expect(user).to be_invalid
        expect(user.errors[:password_confirmation]).to be_present
      end
    end

    context "形式" do
      it "6文字未満は無効" do
        user = build(:user, password: "passw", password_confirmation: "passw")
        expect(user).to be_invalid
        expect(user.errors[:password]).to be_present
      end
    end
  end
end
