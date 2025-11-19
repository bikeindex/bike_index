# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationCell::Component, type: :component do
  let(:component) { with_request_url("/admin") { render_inline(described_class.new(**options)) } }
  let(:options) { {organization:, organization_id:, render_search:} }
  let(:organization) { nil }
  let(:organization_id) { nil }
  let(:render_search) { true }

  context "without organization" do
    it "renders nothing" do
      expect(component.to_html.strip).to be_blank
    end
  end

  context "with organization_id only" do
    let(:organization_id) { FactoryBot.create(:organization, name: "Org by ID").id }

    it "looks up and renders organization by id" do
      expect(component.text).to include("Org by ID")
      expect(component).to have_css("a[href='/admin/organizations/#{organization_id}']")
    end
  end

  context "with missing organization_id" do
    let(:organization_id) { 99999999 }

    it "renders missing organization warning" do
      expect(component.text).to include("Missing organization")
      expect(component).to have_css("small.tw:text-red-800")
      expect(component.text).to include("99999999")
      expect(component).to have_css("code.small")
      expect(component).to have_css("a[href='/admin/organizations/99999999']")
    end
  end

  context "with organization" do
    let(:organization) { FactoryBot.create(:organization, name: "Test Organization") }

    it "renders organization name as link" do
      expect(component.text).to include("Test Organization")
      expect(component).to have_css("a[href*='/admin/organizations/']")
      expect(component.text).not_to include("deleted!")
    end
  end

  context "with deleted organization" do
    let(:organization) { FactoryBot.create(:organization, name: "Deleted Org", deleted_at: Time.current - 1) }

    it "renders organization name with less emphasis" do
      expect(component.text).to include("Deleted Org")
      expect(component).to have_css("span.less-strong")
      expect(component.text).to include("deleted!")
      expect(component).to have_css("span.tw:text-red-800")
      expect(component).to have_css("small")
      expect(component).to have_css("a.display-sortable-link")
    end
  end

  context "without render_search" do
    let(:organization) { FactoryBot.create(:organization, name: "Search Test Org") }
    let(:render_search) { false }

    it "renders organization name" do
      expect(component.text).to include("Search Test Org")
      expect(component).not_to have_css("a.display-sortable-link")
    end
  end
end
