require "rails_helper"

RSpec.describe CustomerContact, type: :model do
  describe "validations" do
    subject { FactoryBot.build(:customer_contact) }

    it "validates presence of title" do
      expect(subject).to be_valid
      subject.title = nil
      expect(subject).to be_invalid
    end

    it "validates presence of body" do
      expect(subject).to be_valid
      subject.body = nil
      expect(subject).to be_invalid
    end

    it "validates presence of contact_type" do
      expect(subject).to be_valid
      subject.contact_type = nil
      expect(subject).to be_invalid
    end

    it "validates presence of bike" do
      expect(subject).to be_valid
      subject.bike_id = 999
      expect(subject).to be_invalid
    end

    it "validates presence of creator_email" do
      expect(subject).to be_valid
      subject.creator_email = nil
      expect(subject).to be_invalid
    end

    it "validates presence of user_email" do
      expect(subject).to be_valid
      subject.user_email = nil
      expect(subject).to be_invalid
    end
  end

  describe "normalize_emails_and_find_users" do
    it "finds user by email and associates to user" do
      user = FactoryBot.create(:user)
      cc = FactoryBot.build(:customer_contact, user: nil, user_email: user.email)

      cc.normalize_emails_and_find_users
      cc.save

      expect(cc.user_id).to eq(user.id)
    end

    it "finds creator by email and associates to creator" do
      creator = FactoryBot.create(:user)
      cc = FactoryBot.build(:customer_contact, creator: nil, creator_email: creator.email)

      cc.normalize_emails_and_find_users
      cc.save

      expect(cc.creator_id).to eq(creator.id)
    end

    it "has before_save_callback_method defined as a before_save callback" do
      callback_names =
        CustomerContact
          ._save_callbacks
          .select { |cb| cb.kind.eql?(:before) }
          .map(&:raw_filter)

      expect(callback_names).to include(:normalize_emails_and_find_users)
    end
  end
end
