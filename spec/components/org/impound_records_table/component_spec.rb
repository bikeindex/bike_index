# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::ImpoundRecordsTable::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/impound_records") do
      unless vc_test_controller.class.method_defined?(:sort_column)
        vc_test_controller.class.define_method(:sort_column) { "created_at" }
        vc_test_controller.class.define_method(:sort_direction) { "desc" }
        vc_test_controller.class.helper_method :sort_column, :sort_direction
      end
      render_inline(instance)
    end
  end
  let(:options) do
    {impound_records: [impound_record], current_organization: organization,
     render_sortable:, render_resolved_at:, skip_status:, skip_bike:, skip_location:, skip_multiselect:}
  end
  let(:render_sortable) { false }
  let(:render_resolved_at) { false }
  let(:skip_status) { false }
  let(:skip_bike) { false }
  let(:skip_location) { nil }
  let(:skip_multiselect) { false }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[impound_bikes impound_bikes_locations]) }
  let(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization:) }

  it "renders the table with the impound row" do
    expect(component).to have_css("table")
    expect(component).to have_css("tbody tr", count: 1)
    expect(component).to have_content(impound_record.display_id)
    expect(component).to have_content("ID")
    expect(component).to have_content("Status")
    expect(component).to have_content("Location")
    expect(component).to have_content("Bike")
    expect(component).to have_content("last updator")
    expect(component).to have_content("Impounded from")
    expect(component).to have_link(href: Rails.application.routes.url_helpers.organization_impound_record_path(impound_record.display_id, organization_id: impound_record.organization_id))
    expect(component).to have_css("a[data-action='org--impound-multi-update#selectAll']")
    expect(component).to have_css("td.multi-update-cell.canupdate-note")
    expect(component).to have_css("input[type='checkbox'][name=\"ids[#{impound_record.id}]\"]")
  end

  context "with skip_status and render_resolved_at" do
    let(:skip_status) { true }
    let(:render_resolved_at) { true }

    it "omits the status column and includes Resolved" do
      expect(component).not_to have_content("Status")
      expect(component).to have_content("Resolved")
    end
  end

  context "with skip_bike" do
    let(:skip_bike) { true }

    it "omits the bike column" do
      expect(component).not_to have_content("Bike")
    end
  end

  context "with skip_location true" do
    let(:skip_location) { true }

    it "omits the location column" do
      expect(component).not_to have_content("Location")
    end
  end

  context "without impound_bikes_locations enabled" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[impound_bikes]) }

    it "omits the location column by default" do
      expect(component).not_to have_content("Location")
    end
  end

  context "with skip_multiselect" do
    let(:skip_multiselect) { true }

    it "omits the multiselect column" do
      expect(component).not_to have_css("a[data-action='org--impound-multi-update#selectAll']")
      expect(component).not_to have_css(".multi-update-cell")
    end
  end
end
