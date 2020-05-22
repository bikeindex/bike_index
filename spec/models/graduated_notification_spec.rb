require "rails_helper"


RSpec.describe GraduatedNotification, type: :model do
  let(:graduated_notification_interval) { 2.days.to_i }
  let(:organization) do
    FactoryBot.create(:organization_with_paid_features,
                      enabled_feature_slugs: ["graduated_notifications"],
                      graduated_notification_interval: graduated_notification_interval)
  end
  describe "factories" do
    let(:graduated_notification) { FactoryBot.create(:graduated_notification, organization: organization) }
    let(:bike) { graduated_notification.bike }
    it "is valid" do
      expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      expect(organization.deliver_graduated_notifications?).to be_truthy
      expect(graduated_notification).to be_valid
      expect(graduated_notification.send("calculated_main_notification").id).to eq graduated_notification.id
      expect do
        graduated_notification.process_notification!
      end.to change(BikeOrganization, :count).by(-1)
      expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
      graduated_notification.reload
      expect(graduated_notification.status).to eq "delivered"
      expect(graduated_notification.active?).to be_truthy
      expect(graduated_notification.user).to be_blank
      expect(graduated_notification.send_email?).to be_truthy
      expect(graduated_notification.email).to eq bike.owner_email
      expect(bike.graduated?(organization)).to be_truthy
    end
    context "organization doesn't have graduated_interval set" do
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
  end

  describe "calculated_primary_bike" do
    before do
      bike2.current_ownership.update_attributes(created_at: Time.current - 6.months)
      bike1.current_ownership.update_attributes(created_at: Time.current - 1.year)
    end
    context "user" do
      let(:user) { FactoryBot.create(:user) }
      let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, user: user) }
      let(:bike2) { FactoryBot.create(:bike_organized, :stolen, :with_ownership, organization: organization, user: user) }
      it "finds the first bike" do
        _bike3 = FactoryBot.create(:bike_organized, :with_ownership, organization: organization) # Test to ensure that we aren't grabbing bikes that aren't due notification
        expect(GraduatedNotification.bikes_to_notify_without_notifications(organization).pluck(:id)).to eq([bike1.id, bike2.id])
        # expect(GraduatedNotification.bikes_to_notify_expired_notifications(organization).pluck(:id)).to match_array([])
        expect(GraduatedNotification.bike_ids_to_notify(organization)).to eq([bike1.id, bike2.id])
        expect(GraduatedNotification.count).to eq 0
        graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
        expect(GraduatedNotification.count).to eq 1
        expect(graduated_notification2.main_notification?).to be_falsey
        graduated_notification2.reload
        expect(graduated_notification2.primary_bike?).to be_falsey
        expect(graduated_notification2.primary_bike).to eq bike1
        expect(graduated_notification2.send_email?).to be_falsey
        graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
        expect(GraduatedNotification.count).to eq 2
        graduated_notification1.reload
        expect(graduated_notification1.main_notification?).to be_truthy
        expect(graduated_notification1.primary_bike?).to be_truthy
        expect(graduated_notification1.primary_bike).to eq bike1
        expect(graduated_notification1.send_email?).to be_truthy

        graduated_notification2.reload
        expect(graduated_notification2.primary_notification_id).to eq graduated_notification1.id

        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([graduated_notification2.id])
        # And test that we update to set the primary notification on the other one after creation
        graduated_notification2.reload
        expect(graduated_notification2.main_notification?).to be_falsey
      end
    end
    context "not user" do
      let(:email) { "stuff@example.com" }
      let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, owner_email: email) }
      let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, owner_email: email) }
      it "finds the primary bike, outside of the interval" do
        graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
        graduated_notification1.process_notification!
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([])
        expect(graduated_notification1.main_notification?).to be_truthy
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
        expect(graduated_notification2.main_notification?).to be_falsey
        expect(graduated_notification2.primary_bike?).to be_falsey
        expect(graduated_notification2.primary_bike).to eq bike1
        expect(graduated_notification2.send_email?).to be_falsey
        graduated_notification1.update_attributes(updated_at: Time.current)
        graduated_notification1.reload
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([])

        graduated_notification3 = GraduatedNotification.create(organization: organization, bike: bike1)
        expect(graduated_notification3.associated_notifications.pluck(:id)).to eq([graduated_notification2.id])
        expect(graduated_notification3.main_notification?).to be_truthy
        expect(graduated_notification3.primary_bike?).to be_truthy
        expect(graduated_notification3.primary_bike).to eq bike1
        expect(graduated_notification3.send_email?).to be_truthy

        # And since we've sent these notifications, the bikes aren't around anymore
        expect(organization.bikes.pluck(:id)).to match_array([])
      end
    end
  end

  # This overlaps with some of the above tests, but it's separate to ensure coverage
  describe "bike assigned after creation" do
    let(:period_start) { Time.current - 8.days }
    let(:bike1) { FactoryBot.create(:bike_organized, created_at: period_start, organization: organization) }
    let(:user) { FactoryBot.create(:user) }
    let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership_claimed, created_at: period_start + 4.days, user: user, organization: organization) }
    let(:ownership_later) { FactoryBot.build(:ownership_claimed, bike: bike1, user: user) }
    it "it is still main notification" do
      graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
      graduated_notification1.created_at = period_start + 2.days
      graduated_notification1.mark_remaining!
      expect(graduated_notification1.main_notification?).to be_truthy
      ownership_later.save
      graduated_notification1.reload
      expect(graduated_notification1.main_notification).to eq self
      expect(graduated_notification1.main_notification?).to be_truthy
      expect(graduated_notification1.primary_bike).to eq bike1

      graduated_notification1_again = GraduatedNotification.create(organization: organization, bike: bike1)
      expect(graduated_notification1_again.main_notification?).to be_falsey
      expect(graduated_notification1_again.main_notification).to be_blank
      expect(graduated_notification1_again.primary_bike).to eq bike2

      graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
      expect(graduated_notification1_again.main_notification&.id).to eq graduated_notification2.id
      expect(graduated_notification2.main_notification?).to be_truthy
      expect(graduated_notification2.primary_bike).to eq bike2
      expect(graduated_notification2.send_email?).to be_truthy
      expect(graduated_notification2.associated_notifications.pluck(:id)).to eq([graduated_notification1_again.id])
    end
  end

  describe "bike_organization recreated after graduated_notification sent" do
    let(:bike) { FactoryBot.create(:bike_organized, created_at: Time.current - 2*graduated_notification_interval, organization: organization) }
    let!(:bike_organization1) { bike.bike_organizations.where(organization_id: organization.id).first }
    let(:graduated_notification1) do
      expect(bike_organization1.deleted?).to be_falsey
      bike_organization1_id = bike_organization1.id
      graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
      graduated_notification1.update(created_at: Time.current - graduated_notification_interval - 1.day)
      graduated_notification1.reload
      graduated_notification1
    end
    it "marks the graduated_notification remaining, removes the more recent bike_organization" do
      expect(graduated_notification1.main_notification?).to be_truthy
      expect(graduated_notification1.bike_organization.id).to eq bike_organization1_id
      expect(BikeOrganization.unscoped.find(bike_organization1_id).deleted?).to be_truthy
    end
    context "another graduated_notification sent" do
      it "marks the more recent graduated_notification remaining as well" do
        expect(graduated_notification1.main_notification?).to be_truthy
        expect(graduated_notification1.bike_organization.id).to eq bike_organization1_id
        expect(BikeOrganization.unscoped.find(bike_organization1_id).deleted?).to be_truthy
        bike_organization2 = FactoryBot.create(:bike_organization, bike: bike, organization: organization)
        graduated_notification1.reload
        expect(graduated_notification1.bike_organization.id).to eq bike_organization1_id
        graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike1)
        expect(graduated_notification2.bike_organization.id).to eq bike_organization2.id
        graduated_notification1.mark_remaining
        graduated_notification1.reload
        graduated_notification2.reload
        expect(graduated_notification1.marked_remaining?).to be_truthy
        expect(graduated_notification2.marked_remaining?).to be_truthy
        expect(bike_organization1.deleted?).to be_falsey
        expect(bike_organization2.deleted?).to be_truthy
      end
    end
  end
end

