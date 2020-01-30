RSpec.shared_context :organization_with_geolocated_messages do
  let(:organization) { FactoryBot.create(:organization) }
  let(:paid_feature) { FactoryBot.create(:paid_feature, feature_slugs: %w[messages geolocated_messages]) }
  let!(:invoice) do
    inv = FactoryBot.create(:invoice_paid, organization: organization)

    Sidekiq::Testing.inline! do
      # we have to create the invoice first
      inv = FactoryBot.create(:invoice_paid, organization: organization)
      inv.update_attributes(paid_feature_ids: [paid_feature&.id])
      organization.reload
    end

    inv
  end
end
