require "spec_helper"

describe CustomerContact do
  describe "normalize_email_and_find_user" do
    it "finds email and associate" do
      user = FactoryBot.create(:user)
      cc = CustomerContact.new
      allow(cc).to receive(:user_email).and_return(user.email)
      cc.normalize_email_and_find_user
      expect(cc.user_id).to eq(user.id)
    end
    it "has before_save_callback_method defined as a before_save callback" do
      expect(CustomerContact._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:normalize_email_and_find_user)).to eq(true)
    end
  end
end
