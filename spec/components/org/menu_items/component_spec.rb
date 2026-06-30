# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::MenuItems::Component, type: :component do
  let(:instance) { described_class.new(organization:, current_user:) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/dashboard") { render_inline(instance) }
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  it "renders nav links, dividers, and disabled placeholders (incl. the dashboard route override)" do
    expect(instance.render?).to be true
    expect(organization.overview_dashboard?).to be false
    expect(component.css("li").length).to be > 0
    expect(component.css("a.nav-link").map(&:text).map(&:strip)).to include(
      "#{organization.short_name} Bikes",
      "Add a bike",
      "#{organization.short_name} dashboard"
    )
    expect(component.css("li.divider-nav-item").length).to be > 0
    expect(component.css("span.disabled-menu-item").map(&:text).map(&:strip))
      .to include("Registration stickers")
  end

  context "is_dropdown: true" do
    let(:instance) { described_class.new(organization:, current_user:, is_dropdown: true) }
    let(:non_dropdown) do
      with_request_url("/o/#{organization.to_param}/dashboard") {
        render_inline(described_class.new(organization:, current_user:))
      }
    end

    it "skips disabled placeholders and the trailing divider for non-superusers" do
      expect(component.css("span.disabled-menu-item")).to be_empty
      expect(component.css("li.divider-nav-item").length).to be < non_dropdown.css("li.divider-nav-item").length
    end

    context "as a superuser" do
      let(:current_user) { FactoryBot.create(:superuser) }

      it "keeps the trailing divider" do
        expect(component.css("li.divider-nav-item").length).to eq non_dropdown.css("li.divider-nav-item").length
      end
    end
  end

  context "with no organization" do
    it "does not render" do
      expect(described_class.new(organization: nil, current_user: nil).render?).to be false
    end
  end

  context "as a superuser" do
    let(:current_user) { FactoryBot.create(:superuser) }

    it "renders the super admin link" do
      super_admin = component.css("li.less-strong a").map(&:text).map(&:strip)
      expect(super_admin).to include("Super Admin for #{organization.short_name}")
    end
  end

  describe "route overrides" do
    context "on bulk_imports without show_bulk_import?" do
      let(:component) do
        with_request_url("/o/#{organization.to_param}/bulk_imports") { render_inline(instance) }
      end

      it "renders the injected bulk imports link with a divider above it" do
        expect(organization.show_bulk_import?).to be false
        items = component.css("li").to_a
        bulk_link_index = items.index { |li| li.css("a.nav-link").text.strip == "Bulk Imports" }
        expect(bulk_link_index).to be > 0
        expect(items[bulk_link_index - 1]["class"].to_s).to include("divider-nav-item")
      end
    end

    context "on a normal page" do
      let(:component) do
        with_request_url("/o/#{organization.to_param}/registrations") { render_inline(instance) }
      end

      it "does not inject the dashboard or bulk imports link" do
        labels = component.css("a.nav-link").map(&:text).map(&:strip)
        expect(labels).not_to include("#{organization.short_name} dashboard")
        expect(labels).not_to include("Bulk Imports", "Ascend Imports")
      end
    end

    context "as a superuser, with the org lacking the registration_sequences feature" do
      let(:current_user) { FactoryBot.create(:superuser) }

      it "injects an active Manage Registration sequences link on the sequences and pages controllers" do
        expect(organization.enabled?("registration_sequences")).to be false
        ["/o/#{organization.to_param}/registration_sequences",
          "/o/#{organization.to_param}/registration_sequence_pages/1/edit"].each do |path|
          rendered = with_request_url(path) { render_inline(instance) }
          active = rendered.css("a.nav-link.active").map { |a| a.text.strip }
          expect(active).to include("Manage Registration sequences")
        end
      end

      it "does not inject it on other pages" do
        component = with_request_url("/o/#{organization.to_param}/registrations") { render_inline(instance) }
        expect(component.css("a.nav-link").map { |a| a.text.strip }).not_to include("Manage Registration sequences")
      end
    end
  end
end
