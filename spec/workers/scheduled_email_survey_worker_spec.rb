require "rails_helper"

RSpec.describe ScheduledEmailSurveyWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  let(:organization) { FactoryBot.create(:organization, opted_into_theft_survey_2023: true) }
  let(:user) { FactoryBot.create(:user) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, creation_organization: organization) }

  describe "enqueue workers" do
    let(:user2) { FactoryBot.create(:user, no_non_theft_notification: true) }
    let!(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: user2, creation_organization: organization) }
    let(:bike3) { FactoryBot.create(:bike, :with_ownership_claimed, creation_organization: organization, user: user) }

    it "enqueues expected emails" do
      expect(bike.reload.claimed?).to be_truthy
      expect(bike2.reload.claimed?).to be_truthy
      expect(bike3.reload.claimed?).to be_truthy
      # Test that no_notify is the same for everyone
      expect(instance.send_survey?(bike)).to be_truthy
      expect(instance.send_survey?(bike3)).to be_truthy
      expect(instance.send_survey?(bike2)).to be_falsey

      Sidekiq::Worker.clear_all
      instance.perform
      # It enqueues the bikes that we want - even though some won't be surveyed
      enqueued_ids = ScheduledEmailSurveyWorker.jobs.map { |j| j["args"] }.flatten || []
      expect(enqueued_ids).to match_array([bike.id, bike3.id])

      # Test notification creation
      notification = Notification.create(kind: "theft_survey_2023", user: user, bike: bike)
      expect(notification).to be_valid
      # Notification 2 fails
      notification2 = Notification.create(kind: "theft_survey_2023", user: user2, bike: bike2)
      expect(notification2).to be_valid
      # Now this is falsey, because the user has a notification
      expect(instance.send_survey?(bike3)).to be_falsey
      # But the notification is still valid
      notification3 = Notification.create(kind: "theft_survey_2023", bike: bike3)
      expect(notification).to be_valid
    end
  end

  describe "perform" do
    let!(:mail_snippet) { MailSnippet.create(kind: "theft_survey_2023", subject: "Survey!", body: "Bike Index Registrant,\na Bike Shop - view survey: https://example.com?respid=SURVEY_LINK_ID", is_enabled: true) }
    it "sends a theft survey email" do
      expect(mail_snippet).to be_valid
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 0
      instance.perform(bike.id)
      expect(Notification.count).to eq 1
      notification = Notification.last
      expect(notification.kind).to eq "theft_survey_2023"
      expect(notification.user_id).to eq user.id
      expect(notification.bike_id).to eq bike.id
      expect(notification.notifiable).to be_blank
      expect(notification.delivered?).to be_truthy
      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Survey!")
      expect(mail.from).to eq(["gavin@bikeindex.org"])
      expect(mail.to).to eq([user.email])
      expect(mail.tag).to eq "theft_survey_2023"
      expect(mail.body.encoded.strip).to eq "#{user.name},\r\n#{organization.name} - view survey: https://example.com?respid=1"
      expect(mail.body.encoded).to_not match "supported by"
      # Doing it again doesn't send it
      instance.perform(bike.id)
      expect(Notification.count).to eq 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      # But - with force_send, it sends!
      instance.perform(bike.id, true)
      expect(Notification.count).to eq 2
      expect(ActionMailer::Base.deliveries.count).to eq 2
    end
  end
end
