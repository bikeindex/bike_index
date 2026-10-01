require "rails_helper"

RSpec.describe EmailJobs::OrganizationSignupConfirmationJob, type: :job do
  let!(:organization_signup) { FactoryBot.create(:organization_signup_started) }
  before { OrgServices::Signup.send_confirmation_email(organization_signup) }

  it "sends the confirmation email" do
    ActionMailer::Base.deliveries = []
    described_class.new.perform(organization_signup.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
    expect(Notification.last).to have_attributes(notifiable: organization_signup, kind: "organization_signup_confirmation",
      delivery_status: "delivery_success", message_channel_target: "org_admin@bikeindex.org")
  end

  context "once confirmed" do
    before { OrgServices::Signup.confirm_email!(organization_signup) }

    it "sends nothing" do
      ActionMailer::Base.deliveries = []
      expect { described_class.new.perform(organization_signup.id) }.to_not change(Notification, :count)
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
  end
end
