require "rails_helper"


RSpec.describe GraduatedNotification, type: :model do
  let(:graduated_notification_interval) { 2.days.to_i }
  let(:organization) do
    FactoryBot.create(:organization_with_paid_features,
                      enabled_feature_slugs: ["graduated_notifications"],
                      graduated_notification_interval: graduated_notification_interval)
  end
  describe "factories" do
    let(:delivery_status) { "email_success" }
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
    context "organization doesn't have graduated_interval set" do
      let(:delivery_status) { nil }
      let(:graduated_notification_interval) { nil }
      let(:graduated_notification2) { FactoryBot.create(:graduated_notification) }
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

        # Test scoping of graduated_notification bikes
        expect(graduated_notification2.bike_id).to_not eq bike.id
        expect(graduated_notification2.organization_id).to_not eq organization.id
        expect(GraduatedNotification.bikes.pluck(:id)).to match_array([bike.id, graduated_notification2.bike_id])
        expect(organization.graduated_notifications.bikes.pluck(:id)).to eq([bike.id])
      end
    end
    context "marked_remaining" do
      it "is not active" do
        expect(organization.bikes.pluck(:id)).to eq([])
        graduated_notification.mark_remaining!
        graduated_notification.reload
        expect(graduated_notification).to be_valid
        expect(graduated_notification.status).to eq "marked_remaining"
        expect(graduated_notification.active?).to be_falsey
        expect(graduated_notification.user).to be_blank
        expect(graduated_notification.send_email?).to be_truthy
        expect(graduated_notification.email).to eq bike.owner_email
        expect(bike.graduated?(organization)).to be_falsey
        expect(organization.bikes.pluck(:id)).to eq([bike.id])
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

  describe "bikes_to_notify" do
    let(:user) { FactoryBot.create(:user) }
    let!(:bike1) do
      FactoryBot.create(:bike_organized,
                        :with_ownership_claimed,
                        user: user,
                        organization: organization,
                        created_at: Time.current - 13.days)
    end
    let!(:bike1) do
      FactoryBot.create(:bike_organized,
                        :with_ownership_claimed,
                        user: user,
                        organization: organization,
                        created_at: Time.current - 16.days)
    end
    it "creates for both bikes" do
      expect(GraduatedNotification.bikes_to_notify(organization).pluck(:id)).to eq([bike1.id])
      graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
      expect(graduated_notification1.primary_notification?).to be_truthy
      expect(graduated_notification1.send_email?).to be_truthy
      organization.update(graduated_notification_interval_days: 7)
      expect(GraduatedNotification.bikes_to_notify(organization).pluck(:id)).to eq([bike2.id])
      graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
      expect(graduated_notification2.primary_notification?).to be_falsey
      expect(graduated_notification2.primary_notification).to eq(graduated_notification1)
      expect(graduated_notification2.send_email?).to be_falsey
    end
  end

  describe "calculated_primary_bike" do
    context "user" do
      let(:user) { FactoryBot.create(:user) }
      let!(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, user: user, created_at: Time.current - 1.year) }
      let!(:bike2) { FactoryBot.create(:bike_organized, :stolen, :with_ownership, organization: organization, user: user, created_at: Time.current - 6.months) }
      it "finds the first bike" do
        # Test to ensure ordered correctly - by created_at, not listing order
        expect(Bike.pluck(:id)).to eq([bike2.id, bike1.id])
        expect(GraduatedNotification.bikes_to_notify(organization).pluck(:id)).to eq([bike1.id, bike2.id])
        graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
        expect(graduated_notification2.primary_notification?).to be_truthy
        expect(graduated_notification2.primary_bike?).to be_falsey
        expect(graduated_notification2.primary_bike).to eq bike1
        expect(graduated_notification2.send_email?).to be_falsey
        graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([graduated_notification2.id])
        expect(graduated_notification1.primary_notification?).to be_truthy
        expect(graduated_notification1.primary_bike?).to be_truthy
        expect(graduated_notification1.primary_bike).to eq bike1
        expect(graduated_notification1.send_email?).to be_truthy
        # And test that we update to set the primary notification on the other one after creation
        graduated_notification2.reload
        expect(graduated_notification2.primary_notification?).to be_falsey
      end
    end
    context "not user" do
      let(:email) { "stuff@example.com" }
      let!(:bike1) { FactoryBot.create(:bike_organized, organization: organization, owner_email: email, created_at: Time.current - 1.year) }
      let!(:bike2) { FactoryBot.create(:bike_organized, organization: organization, owner_email: email, created_at: Time.current - 6.months) }
      it "finds the primary bike, outside of the interval" do
        graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([])
        expect(graduated_notification1.primary_notification?).to be_truthy
        expect(graduated_notification1.primary_bike?).to be_truthy
        expect(graduated_notification1.primary_bike).to eq bike1
        expect(graduated_notification1.send_email?).to be_truthy
        expect(organization.bikes.pluck(:id)).to eq([bike2.id])

        graduated_notification1.mark_remaining!
        # Update the original graduated_notification to be before the present interval
        graduated_notification1.update_attributes(delivery_status: "email_success", created_at: bike2.created_at - 8.weeks, marked_remaining_at: bike2.created_at - 3.weeks)
        expect(organization.bikes.pluck(:id)).to match_array([bike1.id, bike2.id])

        # Create a graduated notification that matches a non-primary bike that was marked remaining
        graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
        expect(graduated_notification2.send_email?).to be_falsey
        expect(graduated_notification2.primary_notification?).to be_truthy
        expect(graduated_notification2.primary_bike?).to be_falsey
        expect(graduated_notification2.primary_bike).to eq bike1
        expect(graduated_notification2.send_email?).to be_falsey
        graduated_notification1.update_attributes(updated_at: Time.current)
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([])

        graduated_notification3 = GraduatedNotification.create(organization: organization, bike: bike1)
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([graduated_notification2.id])
        expect(graduated_notification1.primary_notification?).to be_truthy
        expect(graduated_notification1.primary_bike?).to be_truthy
        expect(graduated_notification1.primary_bike).to eq bike1
        expect(graduated_notification1.send_email?).to be_truthy

        # And since we've sent these notifications, the bikes aren't around anymore
        expect(organization.bikes.pluck(:id)).to match_array([])
      end
    end
  end
end

