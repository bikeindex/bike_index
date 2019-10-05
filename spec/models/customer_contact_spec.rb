require "rails_helper"

RSpec.describe CustomerContact, type: :model do
  describe "#possibly_found_notification_sent?" do
    context "given a blank bike" do
      it "returns false" do
        match = FactoryBot.build(:bike)
        already_sent = CustomerContact.possibly_found_notification_sent?(nil, match)
        expect(already_sent).to eq(false)
      end
    end

    context "given a blank matching record" do
      it "returns false" do
        bike = FactoryBot.build(:bike)
        already_sent = CustomerContact.possibly_found_notification_sent?(bike, nil)
        expect(already_sent).to eq(false)
      end
    end

    context "given a bike and match that have already triggered an email to the user" do
      it "returns true" do
        match = FactoryBot.create(:abandoned_bike)
        contact = FactoryBot.create(:customer_contact_potentially_found_bike, match: match)
        bike = contact.bike

        already_sent = CustomerContact.possibly_found_notification_sent?(bike, match)

        expect(already_sent).to eq(true)
      end
    end

    context "given a bike and match where the match has changed" do
      it "returns false" do
        match = FactoryBot.create(:abandoned_bike)
        contact = FactoryBot.create(:customer_contact_potentially_found_bike, match: match)
        bike = contact.bike
        new_match = FactoryBot.create(:abandoned_bike)

        already_sent = CustomerContact.possibly_found_notification_sent?(bike, new_match)

        expect(already_sent).to eq(false)
      end
    end

    context "given a bike and match where the current_stolen_record has changed" do
      it "returns false" do
        match = FactoryBot.create(:abandoned_bike)
        contact = FactoryBot.create(:customer_contact_potentially_found_bike, match: match)
        bike = contact.bike
        bike.update(current_stolen_record: FactoryBot.create(:stolen_record, bike: bike))

        already_sent = CustomerContact.possibly_found_notification_sent?(bike, match)

        expect(already_sent).to eq(false)
      end
    end

    context "given a bike and match where the owner email has changed" do
      it "returns false" do
        match = FactoryBot.create(:abandoned_bike)
        contact = FactoryBot.create(:customer_contact_potentially_found_bike, match: match)
        bike = contact.bike
        bike.update(owner_email: "new_owner@example.com")

        already_sent = CustomerContact.possibly_found_notification_sent?(bike, match)

        expect(already_sent).to eq(false)
      end
    end
  end

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

    it "validates presence of kind" do
      expect(subject).to be_valid
      subject.kind = nil
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

  describe "#receives_stolen_bike_notifications?" do
    context "given no stolen record" do
      it "returns true" do
        customer_contact = FactoryBot.create(:customer_contact)
        result = customer_contact.receives_stolen_bike_notifications?
        expect(result).to eq(true)
      end
    end

    context "given a stolen record that receives notifications" do
      it "returns true" do
        customer_contact = FactoryBot.create(:customer_contact, :stolen_bike)
        result = customer_contact.receives_stolen_bike_notifications?
        expect(result).to eq(true)
      end
    end

    context "given a stolen record that doesn't receive notifications" do
      it "returns false" do
        customer_contact = FactoryBot.create(:customer_contact, :stolen_bike)
        stolen_record = customer_contact.bike.current_stolen_record
        stolen_record.update(receive_notifications: false)
        result = customer_contact.receives_stolen_bike_notifications?
        expect(result).to eq(false)
      end
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
