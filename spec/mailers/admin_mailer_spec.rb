require "rails_helper"

RSpec.describe AdminMailer, type: :mailer do
  let(:feedback) { FactoryBot.create(:feedback) }
  describe "feedback_notification_email" do
    let(:mail) { AdminMailer.feedback_notification_email(feedback) }
    it "renders email" do
      expect(mail.subject).to eq("New Feedback Submitted")
      expect(mail.to).to eq(["contact@bikeindex.org"])
      expect(mail.reply_to).to eq([feedback.email])
      expect(mail.tag).to eq("admin")
      expect(mail.body.encoded).to match "supported by"
    end
  end

  describe "special_feedback_notification_email" do
    let(:feedback) { FactoryBot.create(:feedback, feedback_type: feedback_type, feedback_hash: {bike_id: bike.id}) }
    let(:bike) { FactoryBot.create(:bike) }
    context "a recovery email" do
      let(:feedback_type) { "bike_recovery" }
      it "sends a recovery email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.subject).to eq("New Feedback Submitted")
        expect(mail.to).to eq(["contact@bikeindex.org", "bryan@bikeindex.org", "gavin@bikeindex.org"])
        expect(mail.reply_to).to eq([feedback.email])
        expect(mail.tag).to eq("admin")
      end
    end
    context "a stolen_information email" do
      let(:feedback_type) { "stolen_information" }
      it "sends a stolen_information email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.to).to eq(["bryan@bikeindex.org"])
        expect(mail.tag).to eq("admin")
      end
    end
    context "serial_update" do
      let(:feedback_type) { "serial_update_request" }
      it "sends a serial update email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.subject).to eq("New Feedback Submitted")
        expect(mail.to).to eq(["contact@bikeindex.org"])
        expect(mail.reply_to).to eq([feedback.email])
        expect(mail.tag).to eq("admin")
      end
      context "with a link" do
        let(:feedback) { FactoryBot.create(:feedback, body: "something <a href='sddddd'>ffffff</a> WHAT UP", feedback_type: feedback_type, feedback_hash: {bike_id: bike.id}) }
        it "strips the tag and renders read more" do
          mail = AdminMailer.feedback_notification_email(feedback)
          expect(mail.subject).to eq("New Feedback Submitted")
          expect(mail.body.encoded).to_not match(/<a href=.sddddd/)
          expect(mail.tag).to eq("admin")
        end
      end
    end
    context "org email" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:user) }
      let(:organization_user) { FactoryBot.create(:organization_role_claimed, user: user, organization: organization) }
      let(:feedback) { FactoryBot.create(:feedback, feedback_type: "organization_created", feedback_hash: {organization_id: organization.id}) }
      it "sends a new org email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.to).to eq(["gavin@bikeindex.org", "craig@bikeindex.org"])
        expect(mail.reply_to).to eq([feedback.email])
        expect(mail.tag).to eq("admin")
      end
    end
  end

  context "user_hidden bike" do
    let(:ownership) { FactoryBot.create(:ownership, user_hidden: true) }
    let(:bike) { ownership.bike }
    let(:feedback) { FactoryBot.create(:feedback, feedback_hash: {bike_id: bike.id}, feedback_type: "bike_delete_request") }
    it "doesn't explode" do
      bike.update_attribute :user_hidden, true
      bike.reload
      expect(bike.user_hidden).to be_truthy
      mail = AdminMailer.feedback_notification_email(feedback)
      expect(mail.subject).to eq("New Feedback Submitted")
      expect(mail.to).to eq(["contact@bikeindex.org"])
      expect(mail.reply_to).to eq([feedback.email])
      expect(mail.tag).to eq("admin")
    end
  end

  describe "no_admins_notification_email" do
    before :each do
      @organization = FactoryBot.create(:organization)
      @mail = AdminMailer.no_admins_notification_email(@organization)
    end

    it "renders email" do
      expect(@mail.to).to eq(["contact@bikeindex.org"])
      expect(@mail.subject).to match("doesn't have any admins")
      expect(@mail.tag).to eq("admin")
    end
  end

  describe "blocked_stolen_notification_email" do
    before :each do
      @stolen_notification = FactoryBot.create(:stolen_notification, message: "Test Message", subject: "Test subject")
      @mail = AdminMailer.blocked_stolen_notification_email(@stolen_notification)
    end

    it "renders email" do
      expect(@mail.subject[/blocked/i].present?).to be_truthy
      expect(@mail.body.encoded).to match(@stolen_notification.message)
      expect(@mail.tag).to eq("admin")
    end
  end

  describe "#promoted_alert_notification" do
    context "given notify_of_recovered true" do
      it "renders email with recovered notification" do
        promoted_alert = FactoryBot.create(:promoted_alert_paid)
        mail = described_class.promoted_alert_notification(promoted_alert, notification_type: "promoted_alert_recovered")

        expect(mail.to).to eq(["stolenbikealerts@bikeindex.org"])
        expect(mail.subject).to match("RECOVERED Promoted Alert: #{promoted_alert.id}")
        expect(mail.body.encoded).to include("RECOVERED")
        expect(mail.tag).to eq("admin")
      end
    end
  end
end
