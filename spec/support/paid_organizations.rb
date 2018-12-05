shared_context :organization_with_geolocated_messages do
  let(:paid_feature) { FactoryGirl.create(:paid_feature, feature_slugs: %w[messages geolocated_messages]) }
  let!(:invoice) do
    inv = FactoryGirl.create(:invoice_paid, organization: organization)
    inv.update_attributes(paid_feature_ids: [paid_feature&.id]) # Because we have to create the invoice first
    organization.update_attributes(updated_at: Time.now) # TODO: Rails 5 update - after_commit
    inv
  end
  let(:organization) { FactoryGirl.create(:organization) }
end
