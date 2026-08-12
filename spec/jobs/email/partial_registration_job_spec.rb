require "rails_helper"

RSpec.describe Email::PartialRegistrationJob, type: :job do
  let!(:b_param) { FactoryBot.create(:b_param, owner_email:) }
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

  context "partial_register_confirmation" do
    let!(:b_param) do
      BParam.create(origin: "register_flow", params: {bike: {owner_email:, manufacturer_id: "Trek"}}.as_json)
    end
    before { b_param.generate_email_confirmation_token! }

    it "sends the confirmation email, with the token the flow minted" do
      ActionMailer::Base.deliveries = []
      Email::PartialRegistrationJob.new.perform(b_param.id, "partial_register_confirmation")
      expect(ActionMailer::Base.deliveries.count).to eq 1
      expect(ActionMailer::Base.deliveries.last.subject).to eq "Confirm your email to finish your registration"
      expect(ActionMailer::Base.deliveries.last.html_part.decoded).to include b_param.email_confirmation_token
      expect(Notification.count).to eq 1
      expect(Notification.last).to have_attributes(notifiable: b_param, kind: "partial_register_confirmation",
        user_id: nil, delivery_status: "delivery_success", message_channel_target: owner_email)

      # The token is spent by the time a stale duplicate runs, so there's no link left to send
      b_param.confirm_email!
      expect { Email::PartialRegistrationJob.new.perform(b_param.id, "partial_register_confirmation") }
        .to_not change(Notification, :count)
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end

    # The link is what finishes a report, so the subject says what's being reported
    context "a registration that reports something" do
      let!(:b_param) do
        BParam.create(origin: "register_flow", params: {bike: {owner_email:, manufacturer_id: "Trek",
                                                               cycle_type: "e-scooter", status:}}.as_json)
      end

      {"status_stolen" => "Finish reporting your stolen e-scooter",
       "status_impounded" => "Finish reporting your found e-scooter",
       "status_abandoned" => "Finish reporting your abandoned e-scooter"}.each do |status, subject|
        context status do
          let(:status) { status }

          it "subjects it #{subject.inspect}" do
            ActionMailer::Base.deliveries = []
            Email::PartialRegistrationJob.new.perform(b_param.id, "partial_register_confirmation")
            expect(ActionMailer::Base.deliveries.last.subject).to eq subject
          end
        end
      end
    end

    it "runs the domain check too" do
      stub_const("EmailDomain::VERIFICATION_ENABLED", true)
      FactoryBot.create(:email_domain, domain: "@stuff.org", status: :banned)
      ActionMailer::Base.deliveries = []
      Email::PartialRegistrationJob.new.perform(b_param.id, "partial_register_confirmation")
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(Notification.count).to eq 0
      expect(BParam.count).to eq 0
    end
  end

  context "a kind no b_param sends" do
    it "raises" do
      ActionMailer::Base.deliveries = []
      expect { Email::PartialRegistrationJob.new.perform(b_param.id, "finished_registration") }
        .to raise_error(ArgumentError, /finished_registration/)
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(Notification.count).to eq 0
    end
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

    context "provisional_ban" do
      let(:status) { :provisional_ban }

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
