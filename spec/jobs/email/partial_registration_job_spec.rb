require "rails_helper"

RSpec.describe Email::PartialRegistrationJob, type: :job do
  let!(:b_param) { b_param = FactoryBot.create(:b_param, owner_email:) }
  let(:owner_email) { "bikeowner@stuff.org" }

  it "sends a partial registration email" do
    expect(b_param.creator_id).to be_present
    expect(Notification.count).to eq 0
    ActionMailer::Base.deliveries = []
    Email::PartialRegistrationJob.new.perform(b_param.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    expect(Notification.count).to eq 1
    notification = Notification.last
    expect(notification.notifiable).to eq b_param
    expect(notification.kind).to eq "partial_registration"
    expect(notification.user_id).to be_blank
    expect(notification.delivery_status).to eq "delivery_success"
    expect(notification.b_param?).to be_truthy
    expect(notification.message_channel_target).to eq b_param.email
  end

  context "with EmailDomain verification" do
    before { stub_const("EmailDomain::VERIFICATION_ENABLED", true) }
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@stuff.org", status:) }
    let(:status) { :permitted }

    it "sends an email" do
      expect(Notification.count).to eq 0
      ActionMailer::Base.deliveries = []
      Email::PartialRegistrationJob.new.perform(b_param.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      expect(Notification.count).to eq 1
      expect(BParam.count).to eq 1
    end

    context "ban_pending" do
      let(:status) { :ban_pending }

      it "does not send an email" do
        expect(Notification.count).to eq 0
        ActionMailer::Base.deliveries = []
        Email::PartialRegistrationJob.new.perform(b_param.id)
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        expect(Notification.count).to eq 0
        expect(BParam.count).to eq 1
      end
    end

    context "banned" do
      let(:status) { :banned }

      it "does not send an email, and deletes the bparam" do
        expect(Notification.count).to eq 0
        ActionMailer::Base.deliveries = []
        Email::PartialRegistrationJob.new.perform(b_param.id)
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        expect(Notification.count).to eq 0
        expect(BParam.count).to eq 0
      end
    end
  end
end
