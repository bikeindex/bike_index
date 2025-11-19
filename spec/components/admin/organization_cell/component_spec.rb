# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationCell::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {organization:, organization_id:, render_search:} }
  let(:organization) { nil }
  let(:organization_id) { nil }
  let(:render_search) { false }

  context "without organization" do
    it "renders nothing" do
      expect(component.to_html.strip).to be_blank
    end
  end

  context "with organization" do
    let(:organization) { FactoryBot.create(:organization, name: "Test Organization") }

    it "renders organization name as link" do
      expect(component.text).to include("Test Organization")
      expect(component.css("a[href*='/admin/organizations/']")).to be_present
    end

    it "does not show deleted indicator" do
      expect(component.text).not_to include("deleted!")
    end
  end

  context "with organization_id only" do
    let(:organization) { FactoryBot.create(:organization, name: "Org by ID") }
    let(:organization_id) { organization.id }

    it "looks up and renders organization by id" do
      expect(component.text).to include("Org by ID")
      expect(component.css("a[href='/admin/organizations/#{organization.id}']")).to be_present
    end
  end

  context "with missing organization_id" do
    let(:organization_id) { 99999999 }

    it "renders missing organization warning" do
      expect(component.text).to include("Missing organization")
      expect(component.css("small.text-danger")).to be_present
    end

    it "displays the organization_id" do
      expect(component.text).to include("99999999")
      expect(component.css("code.small")).to be_present
    end

    it "still renders link to organization path" do
      expect(component.css("a[href='/admin/organizations/99999999']")).to be_present
    end
  end

  context "with deleted organization" do
    let(:organization) { FactoryBot.create(:organization, name: "Deleted Org") }

    before do
      organization.destroy
    end

    it "renders organization name with less emphasis" do
      expect(component.text).to include("Deleted Org")
      expect(component.css("span.less-strong")).to be_present
    end

    it "shows deleted indicator" do
      expect(component.text).to include("deleted!")
      expect(component.css("span.text-danger")).to be_present
    end

    it "wraps content in small tag" do
      expect(component.css("small")).to be_present
    end
  end

  context "without render_search" do
    let(:organization) { FactoryBot.create(:organization, name: "Search Test Org") }
    let(:render_search) { false }

    it "renders organization name" do
      expect(component.text).to include("Search Test Org")
    end

    it "does not render search link" do
      expect(component.css("a.display-sortable-link")).to be_blank
    end
  end
end
