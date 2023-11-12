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
      expect(UpdateModelAuditWorker.jobs.count).to eq 0
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
    let!(:manufacturer_organization) { FactoryBot.create(:organization_with_organization_features, manufacturer: manufacturer, enabled_feature_slugs: ["official_manufacturer"]) }
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

  describe "UpdateModelAuditWorker" do
    let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["model_audits"]) }
    let(:model_audit) { FactoryBot.create(:model_audit) }
    let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, model_audit: model_audit, manufacturer: model_audit.manufacturer, frame_model: model_audit.frame_model) }
    it "enqueues all the model model_audits" do
      # there might be a more performant way of dealing with this but I think this is good enough
      Sidekiq::Worker.clear_all
      expect(OrganizationModelAudit.count).to eq 0
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! do
        instance.perform(organization.id)
      end
      expect(bike.reload.model_audit_id).to eq model_audit.id
      expect(model_audit.reload.matching_bike?(bike)).to be_truthy
      expect(OrganizationModelAudit.count).to eq 1
    end
  end

  describe "organization_stolen_message" do
    let(:organization) { FactoryBot.create(:organization, :in_nyc) }
    # Have to do this whole dance because factories inline sidekiq processing of this job
    let(:organization_feature) { FactoryBot.create(:organization_feature, feature_slugs: ["organization_stolen_message"]) }
    let(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization, subscription_start_at: Time.current - 6.months) }
    it "adds it and disables it" do
      expect(organization.reload.organization_stolen_message).to be_blank
      invoice.update(organization_feature_ids: [organization_feature.id])
      instance.perform(organization.id)
      expect(organization.reload.enabled_feature_slugs).to eq(["organization_stolen_message"])
      organization_stolen_message = organization.reload.organization_stolen_message
      expect(organization_stolen_message).to be_present
      expect(organization_stolen_message.is_enabled).to be_falsey
      expect(organization_stolen_message.kind).to eq "association"
      organization_stolen_message.update(body: "stuff", is_enabled: true)
      expect(organization_stolen_message.reload.is_enabled).to be_truthy
      invoice.update(subscription_end_at: Time.current - 1.day)
      instance.perform(organization.id)
      expect(organization.reload.enabled_feature_slugs).to eq([])
      expect(organization_stolen_message.reload.is_enabled).to be_falsey
    end
  end
end
