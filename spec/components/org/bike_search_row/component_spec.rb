# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeSearchRow::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/bikes") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[bike_search]) }
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
  let(:options) { {bike:, organization:, sortable_search_params: {}} }

  it "renders" do
    expect(component.to_html).to include(bike.owner_email)
    expect(component.to_html).to include(bike.mnfg_name)
  end
end
