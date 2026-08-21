# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationTabs::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, name: "Cool Bikes") }
  let(:active) { :show }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(organization:, active:, **options)) }

  it "renders the organization and every tab, with the active one marked" do
    expect(component).to have_content("Cool Bikes")
    expect(component.css(".nav-tabs .nav-link").map { |tab| tab.text.squish })
      .to eq ["Show", "Edit", "Locations 0", "Edit paid functionality", "Invoices"]
    expect(component.css(".nav-tabs .nav-link.active").map { |tab| tab.text.squish }).to eq ["Show"]
    expect(component).to have_link("Edit", href: "/admin/organizations/#{organization.to_param}/edit")
  end

  describe "the SSO tab" do
    it "is absent without the feature" do
      expect(component).to_not have_link("SSO")
    end

    context "with saml_sso enabled" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features, name: "Cool Bikes",
          enabled_feature_slugs: "saml_sso")
      end

      it "renders" do
        expect(component).to have_link("SSO", href: "/admin/organizations/#{organization.to_param}/sso")
      end
    end

    # The page renders either way, saying the feature is off - so it can't be the one page
    # in the section without its own tab
    context "on the SSO tab without the feature" do
      let(:active) { :sso }

      it "renders it, active" do
        expect(component.css(".nav-tabs .nav-link.active").map { |tab| tab.text.squish }).to eq ["SSO"]
      end
    end
  end

  describe "the top right link" do
    let(:organized_view) { component.at_css(".admin-subnav ul .nav-item a") }

    context "on show" do
      it "links to the organization's dashboard" do
        expect(organized_view.text.squish).to eq "organization's view"
        expect(organized_view["href"]).to eq "/o/#{organization.to_param}"
      end
    end

    context "on edit" do
      let(:active) { :edit }

      it "links to the organization's profile" do
        expect(organized_view["href"]).to eq "/o/#{organization.to_param}/manage"
      end
    end

    context "on locations" do
      let(:active) { :locations }

      it "links to the organization's locations" do
        expect(organized_view["href"]).to eq "/o/#{organization.to_param}/manage/locations"
      end
    end

    context "on custom layouts" do
      let(:active) { :custom_layouts }

      it "links to the organization's emails" do
        expect(organized_view["href"]).to eq "/o/#{organization.to_param}/emails"
      end
    end

    context "on invoices" do
      let(:active) { :invoices }

      it "is New Invoice rather than the organization's view" do
        expect(component).to have_link("New Invoice",
          href: "/admin/organizations/#{organization.to_param}/invoices/new")
        expect(component).not_to have_link("organization's view")
      end
    end
  end

  context "with locations" do
    before { FactoryBot.create_list(:location, 2, organization:) }

    it "counts them in the tab" do
      expect(component.css(".nav-tabs .nav-link").map { |tab| tab.text.squish }).to include "Locations 2"
    end
  end

  context "with an invalid active tab" do
    let(:active) { :bikes }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /bikes/)
    end
  end

  context "on the custom layouts tab" do
    let(:active) { :custom_layouts }

    it "renders it, though display_dev_info? is false in test" do
      expect(component.css(".nav-tabs .nav-link.active").map { |tab| tab.text.squish }).to eq ["Custom layouts"]
    end
  end

  context "with a subtitle and an additional link" do
    let(:active) { :custom_layouts }
    let(:options) do
      {subtitle: "Finished Registration", additional_link: "<a href='/somewhere'>Party</a>".html_safe}
    end

    it "renders them alongside the organization's view" do
      expect(component.at_css("h1").text.squish).to eq "Cool Bikes Finished Registration"
      expect(component).to have_link("Party", href: "/somewhere")
      expect(component).to have_link("organization's view", href: "/o/#{organization.to_param}/emails")
    end
  end

  context "with a deleted organization" do
    before { organization.destroy }

    it "renders the deleted alert" do
      expect(component).to have_content("Organization deleted")
    end
  end
end
