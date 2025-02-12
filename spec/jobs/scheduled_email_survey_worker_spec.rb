require "rails_helper"

RSpec.describe ScheduledEmailSurveyWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  let(:stolen_at) { Time.current - 2.weeks } # time in stolen_survey_period
  let(:organization) { FactoryBot.create(:organization, opted_into_theft_survey_2023: true) }
  let(:user) { FactoryBot.create(:user) }
  let(:bike1) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, creation_organization: organization) }
  let!(:stolen_record1) { FactoryBot.create(:stolen_record, bike: bike1, date_stolen: stolen_at) }
  let(:bike_unclaimed) { FactoryBot.create(:bike, :with_ownership, owner_email: user.email, creation_organization: organization) }
  let!(:stolen_record_unclaimed) { FactoryBot.create(:stolen_record, :in_nyc, bike: bike_unclaimed, date_stolen: stolen_at) }

  describe "enqueue workers" do
    let(:user2) { FactoryBot.create(:user, no_non_theft_notification: true) }
    let(:bike2) do
      FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed,
        date_stolen: stolen_at, user: user2, creation_organization: organization)
    end
    let(:bike3) do
      FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed,
        date_stolen: stolen_at, user: user, stolen_no_notify: true)
    end
    let(:bike_recovered) { FactoryBot.create(:bike, :with_ownership, owner_email: "phoebe@example.com") }
    let!(:stolen_record_recovered) { FactoryBot.create(:stolen_record_recovered, :in_nyc, bike: bike_recovered, date_stolen: stolen_at) }
    let!(:bike_outside_survey_period) do
      FactoryBot.create(:bike, :with_stolen_record, :with_ownership, date_stolen: Time.current)
    end
    let(:bike_theft_survey_4_2022) { FactoryBot.create(:stolen_bike, :with_ownership, date_stolen: stolen_at) }
    let!(:theft_survey_4_2022) do
      Notification.create(kind: "theft_survey_4_2022", bike_id: bike_theft_survey_4_2022.id,
        notifiable: bike_theft_survey_4_2022.current_stolen_record, delivery_status: "delivery_success",
        message_channel: :email)
    end
    let!(:bike_outside_us) do
      FactoryBot.create(:stolen_bike_in_amsterdam, :with_ownership, date_stolen: stolen_at)
    end
    let(:target_ids) { [bike1.id, bike_unclaimed.id, bike_recovered.id] }
    let(:all_ids) { {bike1: bike1.id, bike_unclaimed: bike_unclaimed.id, bike2: bike2.id, bike3: bike3.id, bike_recovered: bike_recovered.id, bike_outside_survey_period: bike_outside_survey_period.id, bike_theft_survey_4_2022: bike_theft_survey_4_2022.id, bike_outside_us: bike_outside_us.id} }

    it "enqueues expected emails" do
      expect(bike1.reload.claimed?).to be_truthy
      expect(bike_unclaimed.reload.claimed?).to be_falsey
      expect(bike2.reload.claimed?).to be_truthy
      expect(bike3.reload.claimed?).to be_truthy
      expect(bike_recovered.reload.claimed?).to be_falsey

      expect(instance.send_survey?(bike1)).to be_truthy
      expect(instance.send_survey?(bike2)).to be_falsey # User No non-theft notifications
      expect(instance.send_survey?(bike3)).to be_falsey # Stolen Record no-notify
      expect(instance.send_survey?(bike_recovered)).to be_truthy # recovered
      expect(instance.send_survey?(bike_unclaimed)).to be_truthy
      expect(instance.send_survey?(bike_outside_survey_period.reload)).to be_falsey
      expect(instance.send_survey?(bike_theft_survey_4_2022.reload)).to be_falsey
      expect(instance.send_survey?(bike_outside_us.reload)).to be_falsey

      expect(Bike.pluck(:id)).to match_array all_ids.values
      # pp all_ids
      expect(stolen_record_recovered.reload.current).to be_falsey

      Sidekiq::Worker.clear_all
      instance.perform
      # It enqueues the bikes that we want - even though some won't be surveyed
      enqueued_ids = ScheduledEmailSurveyWorker.jobs.map { |j| j["args"] }.flatten || []
      expect(enqueued_ids).to match_array target_ids

      # Test notification creation
      notification = Notification.create(kind: "theft_survey_2023",
        user: user,
        bike: bike1,
        delivery_status: "delivery_success",
        message_channel: :email)
      expect(notification).to be_valid
      expect(notification.message_channel_target).to eq user.email
      # Notification 2 fails
      notification2 = Notification.create(kind: "theft_survey_2023", user: user2, bike: bike2)
      expect(notification2).to be_valid
      # Now this is falsey, because the user has a notification
      expect(instance.send_survey?(bike3)).to be_falsey
      # But the notification is still valid
      notification3 = Notification.create(kind: "theft_survey_2023", bike: bike3)
      expect(notification3).to be_valid
      # Now this is falsey because notification2 has the same email
      expect(instance.send_survey?(bike_unclaimed)).to be_falsey
      # But this is still truthy
      expect(instance.send_survey?(bike_recovered)).to be_truthy
    end
  end

  describe "perform" do
    let!(:mail_snippet) { MailSnippet.create(kind: "theft_survey_2023", subject: "Survey!", body: "Bike Index Registrant,\na Bike Shop - view survey: https://example.com?respid=SURVEY_LINK_ID", is_enabled: true) }
    it "sends a theft survey email" do
      expect(mail_snippet).to be_valid
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 0
      instance.perform(bike1.id)
      expect(Notification.count).to eq 1
      notification = Notification.last
      expect(notification.kind).to eq "theft_survey_2023"
      expect(notification.user_id).to eq user.id
      expect(notification.bike_id).to eq bike1.id
      expect(notification.notifiable).to be_blank
      expect(notification.delivery_success?).to be_truthy
      expect(notification.message_channel_target).to eq user.email
      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Survey!")
      expect(mail.from).to eq(["gavin@bikeindex.org"])
      expect(mail.to).to eq([user.email])
      expect(mail.tag).to eq "theft_survey_2023"
      expect(mail.body.encoded.strip).to eq "#{user.name},\r\n#{organization.name} - view survey: https://example.com?respid=1"
      expect(mail.body.encoded).to_not match "supported by"
      # Doing it again doesn't send it
      instance.perform(bike1.id)
      expect(Notification.count).to eq 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      # And it doesn't send to the unclaimed bike
      instance.perform(bike_unclaimed.id)
      expect(Notification.count).to eq 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      # But - with force_send, it sends!
      instance.perform(bike1.id, true)
      expect(Notification.count).to eq 2
      expect(ActionMailer::Base.deliveries.count).to eq 2
    end
    context "unclaimed bikes" do
      it "sends a theft survey email" do
        expect(mail_snippet).to be_valid
        ActionMailer::Base.deliveries = []
        expect(Notification.count).to eq 0
        instance.perform(bike_unclaimed.id)
        expect(Notification.count).to eq 1
        notification = Notification.last
        expect(notification.kind).to eq "theft_survey_2023"
        expect(notification.user_id).to be_blank
        expect(notification.bike_id).to eq bike_unclaimed.id
        expect(notification.notifiable).to be_blank
        expect(notification.delivery_success?).to be_truthy
        expect(notification.message_channel_target).to eq user.email
        expect(ActionMailer::Base.deliveries.count).to eq 1

        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq("Survey!")
        expect(mail.from).to eq(["gavin@bikeindex.org"])
        expect(mail.to).to eq([user.email])
        expect(mail.tag).to eq "theft_survey_2023"
        expect(mail.body.encoded.strip).to eq "Bike Index Registrant,\r\n#{organization.name} - view survey: https://example.com?respid=1"
        expect(mail.body.encoded).to_not match "supported by"
        # Doing it again doesn't send it
        instance.perform(bike_unclaimed.id)
        expect(Notification.count).to eq 1
        expect(ActionMailer::Base.deliveries.count).to eq 1
        # And it doesn't send to the claimed bike
        instance.perform(bike1.id)
        expect(Notification.count).to eq 1
        expect(ActionMailer::Base.deliveries.count).to eq 1
        # But - with force_send, it sends!
        instance.perform(bike1.id, true)
        expect(Notification.count).to eq 2
        expect(ActionMailer::Base.deliveries.count).to eq 2
      end
    end
  end
end
