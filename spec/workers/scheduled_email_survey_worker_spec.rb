require "rails_helper"

RSpec.describe ScheduledEmailSurveyWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  let(:at) { Time.current - 5.weeks }
  let!(:stolen_record1) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, date_stolen: at).current_stolen_record }
  let(:user1) { stolen_record1.user }

  describe "enqueue workers" do
    let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, date_stolen: at) }
    let!(:stolen_record2) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, date_stolen: at).current_stolen_record }
    let(:user2) { stolen_record2.user }
    let!(:stolen_record3) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, date_stolen: at, user: user2).current_stolen_record }
    let!(:stolen_record_no_notify1) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, date_stolen: at, stolen_no_notify: true).current_stolen_record }
    let!(:stolen_record_no_notify2) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, date_stolen: at, user: user1, stolen_no_notify: true).current_stolen_record }
    let!(:recovered_bike) { FactoryBot.create(:bike, :with_ownership_claimed, date_stolen: at) }
    let!(:recovered_record) { FactoryBot.create(:stolen_record_recovered, date_stolen: at, bike: recovered_bike) }
    it "enqueues expected emails" do
      expect(stolen_record_no_notify2.reload.user&.id).to eq stolen_record1.user.id
      # Test that no_notify is the same for everyone
      expect(stolen_record1.reload.no_notify).to be_falsey
      expect(stolen_record_no_notify1.reload.no_notify).to be_truthy
      expect(stolen_record_no_notify2.reload.no_notify).to be_truthy
      expect(stolen_record2.reload.no_notify).to be_falsey
      expect(stolen_record3.reload.no_notify).to be_falsey
      expect(StolenRecord.recovered.where(bike_id: recovered_bike.id).first.no_notify).to be_falsey
      # Notifications
      notification = Notification.create(kind: "theft_survey_4_2022", user: user2, notifiable: stolen_record3)
      expect(notification).to be_valid
      #
      notification2 = Notification.create(kind: "stolen_notification_sent", user: user1, notifiable: stolen_record1)
      expect(notification2).to be_valid
      Sidekiq::Worker.clear_all
      instance.perform
      expect(instance.send_survey?(stolen_record1)).to be_truthy
      expect(instance.send_survey?(stolen_record2)).to be_falsey # user has theft_survey notification
      expect(instance.send_survey?(stolen_record3)).to be_falsey # stolen record has theft_survey notification
      expect(instance.send_survey?(stolen_record_no_notify1)).to be_falsey # no notify
      expect(instance.send_survey?(stolen_record_no_notify2)).to be_falsey # no notify
      expect(instance.no_survey?(recovered_record)).to be_falsey
      # It enqueues the bikes that we want - even though some won't be surveyed
      enqueued_ids = ScheduledEmailSurveyWorker.jobs.map { |j| j["args"] }.flatten || []
      expect(enqueued_ids).to match_array([stolen_record1.id, recovered_record.id])
    end
  end

  describe "perform" do
    let!(:mail_snippet) { MailSnippet.create(kind: "theft_survey_4_2022", subject: "Survey!", body: "XXXvvvvCCC", is_enabled: true) }
    it "sends a theft survey email" do
      expect(mail_snippet).to be_valid
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 0
      ScheduledEmailSurveyWorker.new.perform(stolen_record1.id)
      expect(Notification.count).to eq 1
      notification = Notification.last
      expect(notification.kind).to eq "theft_survey_4_2022"
      expect(notification.user).to eq user1
      expect(notification.notifiable).to eq stolen_record1
      expect(notification.delivered?).to be_truthy
      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Survey!")
      expect(mail.from).to eq(["gavin@bikeindex.org"])
      expect(mail.to).to eq([user1.email])
      expect(mail.tag).to eq "theft_survey_4_2022"
      expect(mail.body.encoded).to match(/XXXvvvvCCC/i)
      expect(mail.body.encoded).to_not match "supported by"
    end
  end
end
