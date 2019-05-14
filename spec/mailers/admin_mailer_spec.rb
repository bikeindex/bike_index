require "spec_helper"

describe AdminMailer do
  let(:feedback) { FactoryBot.create(:feedback) }
  describe "feedback_notification_email" do
    before :each do
      @mail = AdminMailer.feedback_notification_email(feedback)
    end
    it "renders email" do
      expect(@mail.subject).to eq("New Feedback Submitted")
      expect(@mail.to).to eq(["contact@bikeindex.org"])
      expect(@mail.reply_to).to eq([feedback.email])
    end
  end

  describe "special_feedback_notification_email" do
    let(:feedback) { FactoryBot.create(:feedback, feedback_type: feedback_type, feedback_hash: { bike_id: bike.id }) }
    let(:bike) { FactoryBot.create(:bike) }
    context "a delete request email" do
      let(:feedback_type) { "bike_delete_request" }
      it "sends a delete request email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.subject).to eq("New Feedback Submitted")
        expect(mail.to).to eq(["contact@bikeindex.org"])
        expect(mail.reply_to).to eq([feedback.email])
      end
    end
    context "a recovery email" do
      let(:feedback_type) { "bike_recovery" }
      it "sends a recovery email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.subject).to eq("New Feedback Submitted")
        expect(mail.to).to eq(["contact@bikeindex.org", "bryan@bikeindex.org", "lily@bikeindex.org"])
        expect(mail.reply_to).to eq([feedback.email])
      end
    end
    context "a stolen_information email" do
      let(:feedback_type) { "stolen_information" }
      it "sends a stolen_information email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.to).to eq(["bryan@bikeindex.org"])
      end
    end
    context "serial_update" do
      let(:feedback_type) { "serial_update_request" }
      it "sends a serial update email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.subject).to eq("New Feedback Submitted")
        expect(mail.to).to eq(["contact@bikeindex.org"])
        expect(mail.reply_to).to eq([feedback.email])
      end
      context "with a link" do
        let(:feedback) { FactoryBot.create(:feedback, body: "something <a href='sddddd'>ffffff</a> WHAT UP", feedback_type: feedback_type, feedback_hash: { bike_id: bike.id }) }
        it "strips the tag and renders read more" do
          mail = AdminMailer.feedback_notification_email(feedback)
          expect(mail.subject).to eq("New Feedback Submitted")
          expect(mail.body.encoded).to_not match(/<a href=.sddddd/)
        end
      end
    end
    context "org email" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:user) }
      let(:membership) { FactoryBot.create(:membership, user: user, organization: organization) }
      let(:feedback) { FactoryBot.create(:feedback, feedback_type: "organization_created", feedback_hash: { organization_id: organization.id }) }
      it "sends a new org email" do
        mail = AdminMailer.feedback_notification_email(feedback)
        expect(mail.to).to eq(["lily@bikeindex.org", "craig@bikeindex.org"])
        expect(mail.reply_to).to eq([feedback.email])
      end
    end
  end

  context "user_hidden bike" do
    let(:ownership) { FactoryBot.create(:ownership, user_hidden: true) }
    let(:bike) { ownership.bike }
    let(:feedback) { FactoryBot.create(:feedback, feedback_hash: { bike_id: bike.id }, feedback_type: "bike_delete_request") }
    it "doesn't explode" do
      bike.update_attribute :hidden, true
      bike.reload
      expect(bike.user_hidden).to be_truthy
      mail = AdminMailer.feedback_notification_email(feedback)
      expect(mail.subject).to eq("New Feedback Submitted")
      expect(mail.to).to eq(["contact@bikeindex.org"])
      expect(mail.reply_to).to eq([feedback.email])
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
    end
  end

  describe "unknown_organization_for_ascend_import" do
    let(:bulk_import) { FactoryBot.create(:bulk_import_ascend) }
    let(:mail) { AdminMailer.unknown_organization_for_ascend_import(bulk_import) }

    it "renders email" do
      expect(mail.to).to eq(["lily@bikeindex.org", "craig@bikeindex.org"])
      expect(mail.subject).to match("Unknown organization for ascend import")
    end
  end
end
