require "rails_helper"

RSpec.describe Backfills::BikeSearchSlugRemovalJob, type: :job do
  describe "perform" do
    let!(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[bike_search csv_exports])
    end
    let!(:deleted_organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[bike_search])
        .tap(&:destroy)
    end
    let!(:other_organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[csv_exports])
    end
    let(:invoice) { organization.invoices.first }

    before { invoice.update_column(:child_enabled_feature_slugs, %w[bike_search csv_exports]) }

    it "removes the slug from features, invoices and organizations, leaving the others" do
      expect(organization.enabled_feature_slugs).to eq %w[bike_search csv_exports]

      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(invoice.organization_features.first.feature_slugs).to eq %w[csv_exports]
      expect(invoice.reload.child_enabled_feature_slugs).to eq %w[csv_exports]
      expect(organization.reload.enabled_feature_slugs).to eq %w[csv_exports]
      expect(other_organization.reload.enabled_feature_slugs).to eq %w[csv_exports]
      expect(Organization.unscoped.find(deleted_organization.id).enabled_feature_slugs).to eq []

      # It's calculated from the features, so saving can't bring the slug back
      organization.update(updated_at: Time.current)
      expect(organization.reload.enabled_feature_slugs).to eq %w[csv_exports]
    end
  end
end
