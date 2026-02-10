# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::ImpoundRecordsIndex::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}") do
      # Template partials/helpers require these controller instance variables
      vc_test_controller.instance_variable_set(:@selected_query_items_options, [])
      vc_test_controller.instance_variable_set(:@interpreted_params, {})
      vc_test_controller.instance_variable_set(:@period, "year")
      # SortableTable helper methods
      vc_test_controller.class.helper_method :sort_column, :sort_direction unless vc_test_controller.respond_to?(:sort_column)
      vc_test_controller.define_singleton_method(:sort_column) { "created_at" }
      vc_test_controller.define_singleton_method(:sort_direction) { "desc" }
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:pagy) { Pagy::Offset.new(count: 0, limit: 25, page: 1) }
  let(:options) do
    {
      pagy:,
      impound_records: ImpoundRecord.none,
      search_status: "current",
      search_unregisteredness: "all",
      time_range: (Time.current - 1.year)..Time.current,
      available_statuses: %w[current all],
      current_organization: organization
    }
  end

  it "renders" do
    expect(component).to have_css("form")
    expect(component).to have_content("0 matching impound records")
  end
end
