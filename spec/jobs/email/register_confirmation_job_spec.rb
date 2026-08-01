require "rails_helper"

RSpec.describe Email::RegisterConfirmationJob, type: :job do
  let(:owner_email) { "bikeowner@stuff.org" }
  let!(:b_param) do
    BParam.create(origin: "register_flow",
      params: {bike: {owner_email:, manufacturer_id: "Trek"}}.as_json)
  end
  before { b_param.generate_email_confirmation_token! }

  it "sends the confirmation email, with the token the flow minted" do
    ActionMailer::Base.deliveries = []
    described_class.new.perform(b_param.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
    expect(ActionMailer::Base.deliveries.last.html_part.decoded).to include b_param.email_confirmation_token
    expect(Notification.count).to eq 1
    expect(Notification.last).to have_attributes(notifiable: b_param, kind: "register_confirmation",
      user_id: nil, delivery_status: "delivery_success", message_channel_target: owner_email)
  end

  context "already confirmed" do
    before { b_param.confirm_email! }

    it "sends nothing - there's nothing left to prove" do
      ActionMailer::Base.deliveries = []
      described_class.new.perform(b_param.id)
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(Notification.count).to eq 0
    end
  end

  context "with EmailDomain verification" do
    before { stub_const("EmailDomain::VERIFICATION_ENABLED", true) }
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@stuff.org", status:) }
    let(:status) { :permitted }

    it "sends an email" do
      ActionMailer::Base.deliveries = []
      described_class.new.perform(b_param.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      expect(Notification.count).to eq 1
      expect(BParam.count).to eq 1
    end

    context "provisional_ban" do
      let(:status) { :provisional_ban }

      it "does not send an email" do
        ActionMailer::Base.deliveries = []
        described_class.new.perform(b_param.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(Notification.count).to eq 0
        expect(BParam.count).to eq 1
      end
    end

    context "banned" do
      let(:status) { :banned }

      it "does not send an email, and deletes the b_param" do
        ActionMailer::Base.deliveries = []
        described_class.new.perform(b_param.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(Notification.count).to eq 0
        expect(BParam.count).to eq 0
      end
    end
  end
end
