require "rails_helper"

RSpec.describe Email::NewsletterJob, type: :job do
  let!(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
  let!(:mail_snippet) do
    FactoryBot.create(:mail_snippet, kind: :newsletter, subject: "Bike Index newsletter",
      body: "<p>some body</p>")
  end

  describe "enqueue_for" do
    let!(:user_no_newsletter) { FactoryBot.create(:user_confirmed) }
    let!(:user_unconfirmed) { FactoryBot.create(:user, notification_newsletters: true) }
    let(:user_sent) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
    let!(:notification) { Notification.create(user: user_sent, notifiable: mail_snippet, kind: :newsletter, delivery_status: :delivery_success) }
    let!(:notification_other_newsletter) { Notification.create(user:, notifiable_id: mail_snippet.id + 100, kind: :newsletter, delivery_status: :delivery_success) }
    it "finds the correct users" do
      expect(described_class.users_to_send(mail_snippet.id).pluck(:id)).to eq([user.id])
      Sidekiq::Job.clear_all
      described_class.enqueue_for(mail_snippet.id)
      expect(described_class.jobs.map { |j| j["args"] }.flatten).to eq([user.id, mail_snippet.id])
    end
  end

  describe "perform" do
    let(:target_notification_attrs) do
      {kind: "newsletter", notifiable_type: "MailSnippet", notifiable_id: mail_snippet.id,
       user_id: user.id, delivery_status: "delivery_success"}
    end

    it "sends an email once" do
      ActionMailer::Base.deliveries = []
      expect do
        described_class.new.perform(user.id, mail_snippet.id)
        described_class.new.perform(user.id, mail_snippet.id)
      end.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq(mail_snippet.subject)
      expect(mail.from).to eq(["contact@bikeindex.org"])
      expect(mail.to).to eq([user.email])
      expect(mail.body).to match mail_snippet.body

      notification = Notification.last
      expect(notification).to match_hash_indifferently(target_notification_attrs)
    end

    context "with user without notification_newsletters" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      it "doesn't send, but sends with force_send" do
        expect(user.reload.notification_newsletters).to be_falsey
        ActionMailer::Base.deliveries = []
        expect do
          described_class.new.perform(user.id, mail_snippet.id)
        end.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy

        # but with force send, it sends
        expect do
          described_class.new.perform(user.id, mail_snippet.id, true)
          described_class.new.perform(user.id, mail_snippet.id, true)
        end.to change(Notification, :count).by 2
        expect(ActionMailer::Base.deliveries.count).to eq 2
      end
    end
  end
end
