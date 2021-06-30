require "rails_helper"

RSpec.describe AfterUserChangeWorker, type: :job do
  let(:instance) { described_class.new }

  context "no user" do
    it "does not raise an error" do
      expect(instance.perform(238181813)).to be_falsey
    end
  end

  describe "add_phones_for_verification" do
    let(:phone) { "4334445555" }
    let(:user) { FactoryBot.create(:user, phone: phone) }
    it "adds the phone, in a streamlined way without calling multiple times" do
      user.reload
      expect_any_instance_of(TwilioIntegration).to(receive(:send_message).exactly(1).time) { OpenStruct.new(sid: "asd7c80123123sdddf") }
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! do
        expect {
          instance.perform(user.id)
          user.update(phone: phone)
          user.update(phone: nil)
        }.to change(UserPhone, :count).by 1
      end
      user_phone = UserPhone.last
      expect(user_phone.user_id).to eq user.id
      expect(user_phone.confirmed?).to be_falsey
      expect(user_phone.confirmation_code).to be_present
      expect(user_phone.phone).to eq phone
      expect(user_phone.notifications.count).to eq 1
      expect(user_phone.notifications.last.twilio_sid).to eq "asd7c80123123sdddf"
      # And it doesn't add a mailchimp datum
      expect(MailchimpDatum.count).to eq 0
    end
    context "existing user phone" do
      let(:user_phone) { FactoryBot.create(:user_phone, phone: phone) }
      let(:user) { user_phone.user }
      it "does not add the phone if the phone is present" do
        user.reload
        Sidekiq::Worker.clear_all
        expect {
          instance.perform(user.id)
        }.to_not change(UserPhone, :count)
        expect(AfterUserChangeWorker.jobs.count).to eq 0
        user.update(phone: phone)
        user_phone.destroy
        user.reload
        expect {
          instance.perform(user.id)
        }.to_not change(UserPhone, :count)
        expect(AfterUserChangeWorker.jobs.count).to eq 0
        user.reload
        expect(user.phone).to eq phone
      end
    end
  end

  describe "phone_waiting_confirmation" do
    let(:user) { FactoryBot.create(:admin) } # Confirm that superadmins still get this alert, because we want them to
    let!(:user_phone) { FactoryBot.create(:user_phone, user: user) }
    it "adds alert_slugs" do
      expect {
        instance.perform(user.id)
      }.to change(UserAlert, :count).by 1
      user_alert = user.user_alerts.last
      expect(user_alert.active?).to be_truthy
      expect(user_alert.kind).to eq "phone_waiting_confirmation"
      user.reload
      expect(user.alert_slugs).to eq(["phone_waiting_confirmation"])
    end
    context "legacy_migration" do
      let!(:user_phone) { FactoryBot.create(:user_phone, user: user, confirmation_code: "legacy_migration") }
      it "does not add if it's the only user_phone" do
        expect(user_phone.legacy?).to be_truthy
        expect(user.phone_waiting_confirmation?).to be_falsey
        instance.perform(user.id)
        user.reload
        expect(user.alert_slugs).to eq([])
        # Add another user phone, and it does add the alert though
        FactoryBot.create(:user_phone, user: user)
        expect(user.phone_waiting_confirmation?).to be_truthy
        instance.perform(user.id)
        user.reload
        expect(user.alert_slugs).to eq(["phone_waiting_confirmation"])
      end
    end
  end

  context "feedback" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:user_email) { FactoryBot.create(:user_email, user: user, email: "secondary_email@stuff.com") }
    let(:feedback) { FactoryBot.create(:feedback, email: "secondary_email@stuff.com") }
    it "associates feedbacks" do
      expect(feedback.reload.user_id).to be_blank
      user_email.confirm(user_email.confirmation_token)
      expect(feedback.reload.user_id).to be_blank
      instance.perform(user.id)
      expect(feedback.reload.user_id).to eq user.id
    end
  end

  context "unassigned bikes" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features) }
    let(:user) { FactoryBot.create(:user_confirmed) }
    let!(:bike1) { FactoryBot.create(:bike_organized, :with_ownership_claimed, organization: organization, user: user) }
    let!(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
    it "adds alerts for unassigned bikes" do
      expect(organization.reload.paid?).to be_truthy
      expect(organization.paid_money?).to be_falsey
      expect(organization.bikes.pluck(:id)).to match_array([bike1.id])
      expect(user.bike_organizations.pluck(:id)).to eq([organization.id])
      expect(user.reload.rough_approx_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(user.user_alerts.pluck(:kind)).to eq([])
      instance.perform(user.id)
      user.reload
      expect(user.user_alerts.count).to eq 0
      expect(user.alert_slugs).to eq([])
    end
    context "paid money org" do
      let!(:invoice) { FactoryBot.create(:invoice_with_payment, organization: organization) }
      it "adds alerts for unassigned bikes" do
        expect(organization.reload.paid?).to be_truthy
        expect(organization.paid_money?).to be_truthy
        expect(organization.bikes.pluck(:id)).to match_array([bike1.id])
        expect(user.user_alerts.pluck(:kind)).to eq([])
        instance.perform(user.id)
        user.reload
        expect(user.alert_slugs).to eq(["unassigned_bike_org"])
        expect(user.user_alerts.count).to eq 1
        user_alert = user.user_alerts.last
        expect(user_alert.kind).to eq "unassigned_bike_org"
        expect(user_alert.active?).to be_truthy
        expect(user_alert.organization_id).to eq organization.id
        expect(user_alert.bike_id).to eq bike2.id
      end
    end
  end

  describe "stolen records missing locations" do
    let(:user) { FactoryBot.create(:user) }
    let(:ownership) { FactoryBot.create(:ownership_claimed, creator: user, user: user) }
    let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: ownership.bike, street: "         ") }
    let(:ownership_with_location) { FactoryBot.create(:ownership_claimed, creator: user, user: user) }
    let!(:stolen_record_with_location) { FactoryBot.create(:stolen_record, bike: ownership_with_location.bike, street: "some cool street") }
    let(:ownership_unclaimed) { FactoryBot.create(:ownership, creator: user) }
    let!(:stolen_record_unclaimed) { FactoryBot.create(:stolen_record, bike: ownership_unclaimed.bike) }
    it "lists the bikes with missing locations" do
      # Ensure we've got the current stolen records set
      stolen_record.bike.update_attributes(updated_at: Time.current)
      stolen_record_with_location.bike.update_attributes(updated_at: Time.current)
      stolen_record_unclaimed.bike.update_attributes(updated_at: Time.current)
      expect(stolen_record.bike.current_stolen_record).to eq stolen_record
      expect(stolen_record_with_location.bike.current_stolen_record).to eq stolen_record_with_location
      expect(stolen_record_unclaimed.bike.current_stolen_record).to eq stolen_record_unclaimed
      # Test that the missing location is there
      expect(stolen_record.without_location?).to be_truthy
      expect(stolen_record_with_location.without_location?).to be_falsey
      expect(stolen_record_unclaimed.without_location?).to be_truthy
      expect(stolen_record.bike.user).to eq user
      expect(stolen_record_with_location.bike.user).to eq user
      expect(stolen_record_unclaimed.bike.user).to be_blank
      # Unmemoize the stolen_bike_without_location
      user_id = user.id
      user = User.find(user_id)
      user.save
      expect(stolen_record.bike.status_stolen?).to be_truthy
      expect(stolen_record_with_location.bike.status_stolen?).to be_truthy
      expect(user.rough_approx_bikes.status_stolen.pluck(:id)).to match_array([stolen_record.bike_id, stolen_record_with_location.bike_id])
      expect(user.rough_stolen_bikes.select { |b| b.current_stolen_record.without_location? }.map(&:id)).to eq([stolen_record.bike_id])
      instance.perform(user.id)

      user.reload
      expect(user.alert_slugs).to eq(["stolen_bike_without_location"])

      FactoryBot.create(:theft_alert, stolen_record: stolen_record, user: user)
      instance.perform(user.id)
      user.reload
      expect(user.alert_slugs).to eq(%w[stolen_bike_without_location theft_alert_without_photo])

      membership = FactoryBot.create(:membership_claimed, user: user, role: "admin")
      instance.perform(user.id)
      user.reload
      expect(user.alert_slugs).to eq(["theft_alert_without_photo"])

      membership.destroy
      user.update(superuser: true)
      instance.perform(user.id)
      user.reload
      expect(user.alert_slugs).to eq([])
    end
  end
end
