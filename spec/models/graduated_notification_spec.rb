require "rails_helper"


RSpec.describe GraduatedNotification, type: :model do
  describe "factories" do
    let(:graduated_notification_interval) { 2.days.to_i }
    let(:delivery_status) { "email_success" }
    let(:organization) do
      FactoryBot.create(:organization_with_paid_features,
                        :with_auto_user,
                        enabled_feature_slugs: ["graduated_notifications"],
                        graduated_notification_interval: graduated_notification_interval)
    end
    let(:graduated_notification) { FactoryBot.create(:graduated_notification, organization: organization, delivery_status: delivery_status) }
    let(:bike) { graduated_notification.bike }
    it "is valid" do
      expect(organization.deliver_graduated_notifications?).to be_truthy
      expect(graduated_notification).to be_valid
      expect(graduated_notification.active?).to be_truthy
      expect(graduated_notification.user).to be_blank
      expect(graduated_notification.send_email?).to be_truthy
      expect(graduated_notification.email).to eq bike.owner_email
      expect(bike.graduated?(organization)).to be_truthy
    end
    context "organization doesn't have graduated_interval set, or auto user" do
      let(:delivery_status) { nil }
      let(:organization) do
        FactoryBot.create(:organization_with_paid_features,
                          enabled_feature_slugs: ["graduated_notifications"],
                          graduated_notification_interval: nil)
      end
      it "is valid" do
        expect(organization.deliver_graduated_notifications?).to be_falsey
        expect(graduated_notification).to be_valid
        expect(graduated_notification.active?).to be_falsey
        expect(graduated_notification.user).to be_blank
        expect(graduated_notification.send_email?).to be_falsey
        expect(graduated_notification.email).to eq bike.owner_email
        expect(bike.graduated?(organization)).to be_falsey
        # Test setting graduated_notification_interval_days here, because this is where it matters
        expect(organization.graduated_notification_interval_days).to be_blank
        organization.update(graduated_notification_interval_days: "12")
        organization.reload
        expect(organization.graduated_notification_interval_days).to eq 12
        expect(organization.deliver_graduated_notifications?).to be_truthy
        organization.update(graduated_notification_interval_days: 0)
        organization.reload
        expect(organization.graduated_notification_interval_days).to be_blank
        expect(organization.deliver_graduated_notifications?).to be_falsey
      end
    end
    context "marked_remaining" do
      before do
        graduated_notification.mark_remaining!
        graduated_notification.reload
      end
      it "is not active" do
        expect(graduated_notification).to be_valid
        expect(graduated_notification.status).to eq "marked_remaining"
        expect(graduated_notification.active?).to be_falsey
        expect(graduated_notification.user).to be_blank
        expect(graduated_notification.send_email?).to be_truthy
        expect(graduated_notification.email).to eq bike.owner_email
        expect(bike.graduated?(organization)).to be_falsey
      end
    end
    context "with_secondary_graduated_notification" do
      let(:graduated_notification) { FactoryBot.create(:graduated_notification_with_secondary, organization: organization, delivery_status: delivery_status) }
      let(:secondary_graduated_notification) { graduated_notification.secondary_notifications.first }
      it "has two graduated_notifications" do
        expect(graduated_notification).to be_valid
        expect(graduated_notification.active?).to be_truthy
        expect(bike.ownerships.count).to eq 1
        expect(bike.authorized_by_organization?(org: organization)).to be_truthy
        expect(graduated_notification.email).to eq bike.owner_email
        expect(graduated_notification.active?).to be_truthy
        expect(graduated_notification.user_id).to be_present
        expect(graduated_notification.send_email?).to be_truthy
        expect(graduated_notification.secondary_notifications.pluck(:id)).to eq([secondary_graduated_notification.id])
        expect(graduated_notification.associated_notifications.pluck(:id)).to eq([secondary_graduated_notification.id])
        expect(graduated_notification.associated_notifications_including_self.pluck(:id)).to match_array([graduated_notification.id, secondary_graduated_notification.id])
        expect(secondary_graduated_notification.organization_id).to eq graduated_notification.organization_id
        expect(secondary_graduated_notification.bike_id).to eq bike.id
        expect(graduated_notification.user_id).to eq graduated_notification.user_id
        expect(secondary_graduated_notification.email).to eq bike.owner_email
        expect(secondary_graduated_notification.send_email?).to be_falsey
        expect(bike.graduated?(organization)).to be_truthy
        # Test that marking secondary notification marks the primary notification - not sure how this will happen, but just in case
        secondary_graduated_notification.mark_remaining!
        expect(secondary_graduated_notification.marked_remaining?).to be_truthy
        graduated_notification.reload
        expect(graduated_notification.marked_remaining?).to be_truthy
      end
    end
  end

  # describe "graduated_notification_interval" do
  #   let(:graduated_notification_interval) { 1.week.to_i }
  #   let(:organization) do
  #     FactoryBot.create(:organization_with_paid_features,
  #                       enabled_feature_slugs: ["graduated_notifications"],
  #                       graduated_notification_interval: graduated_notification_interval)
  #   end
  #   let(:user) { FactoryBot.create(:user) }
  #   let!(:bike_after) do
  #     FactoryBot.create(:bike_organized,
  #                       :with_ownership_claimed,
  #                       user: user,
  #                       organization: organization,
  #                       created_at: graduated_notification_interval + 1.hour)
  #   end
  #   let!(:bike_before) do
  #     FactoryBot.create(:bike_organized,
  #                       :with_ownership_claimed,
  #                       user: user,
  #                       organization: organization,
  #                       created_at: graduated_notification_interval - 2.days)
  #   end
  #   it "creates for both bikes" do
  #     expect()
  #   end
  # end
end

