require "rails_helper"

RSpec.describe EmailJobs::ShopWelcomeJob, type: :job do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:auto_user) { user }
  let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", auto_user:) }

  before { ActionMailer::Base.deliveries = [] }

  it "sends the welcome email to the auto user once" do
    described_class.new.perform(organization.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
    expect(ActionMailer::Base.deliveries.last).to have_attributes(to: [user.email], reply_to: ["contact@bikeindex.org"])
    expect(Notification.where(kind: "shop_welcome").count).to eq 1
    expect(Notification.last).to have_attributes(notifiable: organization, user_id: user.id, delivery_status: "delivery_success",
      message_channel_target: user.email)

    expect { described_class.new.perform(organization.id) }.to_not change(Notification, :count)
    expect(ActionMailer::Base.deliveries.count).to eq 1
  end

  context "no auto user" do
    let(:auto_user) { nil }

    it "sends nothing" do
      expect { described_class.new.perform(organization.id) }.to_not change(Notification, :count)
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
  end

  context "not a bike shop" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_advocacy", auto_user:) }

    it "sends nothing" do
      expect { described_class.new.perform(organization.id) }.to_not change(Notification, :count)
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
  end

  context "organization deleted before it runs" do
    it "sends nothing" do
      organization.destroy
      described_class.new.perform(organization.id)
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
  end
end
