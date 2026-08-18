# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::ImpoundRecordsIndex::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}") { render_inline(instance) }
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:pagy) { Pagy::Offset.new(count: 0, limit: 25, page: 1) }
  let(:options) do
    {
      pagy:,
      impound_records: ImpoundRecord.none,
      search_status: "current",
      search_unregisteredness: "all",
      humanized_time_range: "in the past year",
      available_statuses: %w[current all],
      current_organization: organization,
      sort_state: ComponentStates::SortState.new(sort: "created_at", direction: "desc")
    }
  end

  it "renders" do
    expect(component).to have_content(/0\s+matching impound records/)
  end
end
