# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationLandingPagesTable::Component, type: :component do
  let(:component) { with_request_url("/admin/organization_landing_pages") { render_inline(described_class.new(collection: [landing_page], sort_state: ComponentStates::SortState.new(search_params: {period: "all"}), render_search:)) } }
  let(:organization) { FactoryBot.create(:organization) }
  let(:landing_page) { FactoryBot.create(:organization_landing_page, organization:) }
  let(:render_search) { true }

  it "renders a disabled page, with its body length and its links" do
    expect(component.text).to include "Disabled"
    expect(component.text).to_not include "Mismatch"
    expect(component.text).to include ActiveSupport::NumberHelper.number_to_delimited(landing_page.body.size)
    expect(component).to have_css("a[href='/admin/organizations/#{organization.id}/custom_layouts/landing_page/edit']")
    expect(component).to have_css("a[href*='search_item_type=OrganizationLandingPage']")
    expect(component).to have_css("a[href*='organization_id=#{organization.id}']")
  end

  context "render_search false" do
    let(:render_search) { false }

    it "renders the organization without the search link" do
      expect(component.text).to include organization.name
      expect(component).to_not have_css("a[href*='organization_id=#{organization.id}']")
    end
  end

  context "with enabled disagreeing with ORGANIZATIONS_WITH_LANDING_PAGES" do
    let(:landing_page) { FactoryBot.create(:organization_landing_page, organization:, enabled: true) }

    it "renders the mismatch" do
      expect(landing_page.env_enabled?).to be_falsey
      expect(component.text).to include "Enabled"
      expect(component.text).to include "Mismatch"
      expect(component.text).to include landing_page.enabled_mismatch_error
    end
  end
end
