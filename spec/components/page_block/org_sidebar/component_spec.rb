# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::OrgSidebar::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed, email: "kdewey@brakebills.edu") }
  let(:organization) { FactoryBot.create(:organization_brakebills) }
  let!(:organization_role) do
    FactoryBot.create(:organization_role_claimed, user: current_user, organization:, role: "admin")
  end
  let(:page) { {controller_namespace: nil, controller_name: "welcome", action_name: "index"} }
  let(:instance) { described_class.new(organization:, current_user:, **page) }
  let(:component) { with_request_url("/") { render_inline(instance) } }

  it "renders the header, the groups and the account block" do
    expect(component).to have_css "nav#org_sidebar_nav"
    expect(component).to have_text "ADMIN PANEL"
    expect(component).to have_text "Brakebills"

    expect(component.css("[aria-controls^='org_sidebar_group_']").map { |button| button.text.strip })
      .to eq(["Brakebills Registrations", "Impounded Vehicles", "Parking Notifications",
        "Bulk Import & Export", "Brakebills Settings"])

    expect(component).to have_css "button[data-ui--dropdown-target='button']", text: "kdewey@brakebills.edu"
    expect(component.css("ul[role='menu'] li[role='menuitem'] a").map(&:text))
      .to eq(["Your registrations", "Register a new bike", "kdewey@brakebills.edu settings", "Log out"])
  end

  it "opens the first group when no page matches" do
    expect(component.css("[aria-controls^='org_sidebar_group_'][aria-expanded='true']").map { |b| b.text.strip })
      .to eq(["Brakebills Registrations"])
  end

  context "on the impound records page" do
    let(:page) do
      {controller_namespace: "organized", controller_name: "impound_records", action_name: "index"}
    end
    let(:component) { with_request_url("/o/#{organization.to_param}/impound_records") { render_inline(instance) } }

    it "opens the group holding the page, and marks the row current" do
      expect(component.css("[aria-controls^='org_sidebar_group_'][aria-expanded='true']").map { |b| b.text.strip })
        .to eq(["Impounded Vehicles"])
      expect(component).to have_css "a[aria-current='page']", text: "Search Impounded Vehicles"
    end
  end

  # A filtered index is the same controller and action carrying query params, which is
  # why that row matches on controller_action rather than on the path
  context "on a filtered registrations index" do
    let(:page) do
      {controller_namespace: "organized", controller_name: "registrations", action_name: "index"}
    end
    let(:component) do
      with_request_url("/o/#{organization.to_param}/registrations?search_status=stolen") { render_inline(instance) }
    end

    it "keeps the registrations row current" do
      expect(component).to have_css "a[aria-current='page']", text: "Search Registrations"
    end
  end

  # The sequence's pages are their own controller, and the menu has no row of their own
  context "on a registration sequence's pages" do
    let(:page) do
      {controller_namespace: "organized", controller_name: "registration_sequence_pages", action_name: "edit"}
    end
    let(:component) do
      with_request_url("/o/#{organization.to_param}/registration_sequence_pages/2/edit") { render_inline(instance) }
    end

    it "keeps the sequences row current, and its group open" do
      expect(component.css("[aria-controls^='org_sidebar_group_'][aria-expanded='true']").map { |b| b.text.strip })
        .to eq(["Brakebills Settings"])
      expect(component).to have_css "a[aria-current='page']", text: "Manage Registration sequences"
    end
  end

  context "without an organization" do
    let(:instance) { described_class.new(organization: nil, current_user:, **page) }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end

  context "without a current_user" do
    let(:instance) { described_class.new(organization:, current_user: nil, **page) }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
