require "rails_helper"

RSpec.describe UpdateOrganizationAssociationsWorker, type: :job do
  let(:instance) { described_class.new }

  context "multiple organizations" do
    let!(:organization1) { FactoryBot.create(:organization, updated_at: Time.current - 1.hour) }
    let!(:organization2) { FactoryBot.create(:organization, updated_at: Time.current - 2.hours) }
    it "updates the passed organizations" do
      expect(organization1.reload.updated_at).to be < Time.current - 30.minutes
      expect(organization2.reload.updated_at).to be < Time.current - 30.minutes
      Sidekiq::Worker.clear_all
      instance.perform([organization1.id, organization2.id])
      # Make sure we don't reenqueue
      expect(described_class.jobs.count).to eq 0
      expect(organization1.reload.updated_at).to be_within(1).of Time.current
      expect(organization2.reload.updated_at).to be_within(1).of Time.current
    end
  end

  context "regional organization" do
    let!(:regional_child) { FactoryBot.create(:organization, :in_nyc) }
    let!(:regional_parent) { FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc, updated_at: Time.current - 1.hour) }
    it "updates the regional parent too" do
      regional_child.update_column :updated_at, Time.current - 1.hour
      regional_parent.update_column :updated_at, Time.current - 1.hour
      expect(regional_child.reload.updated_at).to be < Time.current - 30.minutes
      expect(regional_parent.reload.updated_at).to be < Time.current - 30.minutes
      Sidekiq::Worker.clear_all

      # Test that the associated_organizations are returning correctly
      expect(instance.associated_organization_ids(regional_child.id)).to match_array([regional_child.id, regional_parent.id])
      expect(instance.associated_organization_ids(regional_parent.id)).to match_array([regional_child.id, regional_parent.id])

      # And actually run the job
      instance.perform([regional_child.id])
      expect(described_class.jobs.count).to eq 0
      expect(regional_child.reload.updated_at).to be_within(1).of Time.current
      expect(regional_parent.reload.updated_at).to be_within(1).of Time.current
    end
  end

  context "organization without location set" do
    let!(:organization) { FactoryBot.create(:organization, :in_nyc) }
    it "updates the regional parent too" do
      expect(organization.locations.count).to eq 1
      organization.update_columns(updated_at: Time.current - 1.hour, location_longitude: nil, location_latitude: nil)
      expect(organization.reload.updated_at).to be < Time.current - 30.minutes
      expect(organization.search_coordinates_set?).to be_falsey
      Sidekiq::Worker.clear_all

      # And actually run the job
      instance.perform([organization.id])
      expect(described_class.jobs.count).to eq 0
      organization.reload

      expect(organization.reload.updated_at).to be_within(1).of Time.current
      expect(organization.search_coordinates_set?).to be_truthy
    end
  end

  context "bump user" do
    let(:user) { FactoryBot.create(:organization_admin) }
    let!(:organization) { user.organizations.first }
    let(:mailchimp_datum) { MailchimpDatum.find_or_create_for(user) }
    it "creates the mailchimp_datum" do
      expect(organization.reload.admins.pluck(:id)).to eq([user.id])
      mailchimp_datum.update(updated_at: Time.current - 1.hour)
      user.reload
      UpdateMailchimpDatumWorker.new # So that it's present post stubbing
      stub_const("UpdateMailchimpDatumWorker::UPDATE_MAILCHIMP", false)
      expect(UpdateMailchimpDatumWorker::UPDATE_MAILCHIMP).to be_falsey
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! do
        organization.update(updated_at: Time.current)
      end
      user.reload
      expect(user.mailchimp_datum).to be_present
      expect(user.mailchimp_datum.lists).to eq(["organization"])
      expect(user.mailchimp_datum.updated_at).to be > Time.current - 1.minute
    end
  end

  describe "organization_manufacturers" do
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let!(:manufacturer_organization) { FactoryBot.create(:organization, manufacturer: manufacturer) }
    let!(:organization) { FactoryBot.create(:organization, kind: "bike_advocacy") }
    let!(:organization2) { FactoryBot.create(:organization, kind: "bike_shop") }
    let!(:bike_shop) { FactoryBot.create(:organization, kind: "bike_shop") }
    let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, manufacturer: manufacturer) }
    let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: bike_shop, manufacturer: manufacturer) }
    it "associates for the manufacturer" do
      expect(OrganizationManufacturer.count).to eq 0
      instance.perform(organization.id)
      instance.perform(organization2.id)
      instance.perform(bike_shop.id)
      expect(OrganizationManufacturer.count).to eq 1
      organization_manufacturer = OrganizationManufacturer.first
      expect(organization_manufacturer.organization_id).to eq bike_shop.id
      expect(organization_manufacturer.manufacturer_id).to eq manufacturer.id
      expect(organization_manufacturer.can_view_counts).to be_falsey
      expect { instance.perform(bike_shop.id) }.to_not change(OrganizationManufacturer, :count)
    end
  end
end
