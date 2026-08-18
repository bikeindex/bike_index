# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::MenuItems::Component, type: :component do
  let(:controller_namespace) { "organized" }
  let(:controller_name) { "dashboard" }
  let(:action_name) { "index" }
  let(:instance) do
    described_class.new(organization:, current_user:, controller_namespace:, controller_name:, action_name:)
  end
  # The controller and action decide which links are injected, not which one is active
  let(:url) { "/o/#{organization.to_param}/#{controller_name}" }
  let(:component) { with_request_url(url) { render_inline(instance) } }
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
    let(:instance) do
      described_class.new(organization:, current_user:, controller_namespace:, controller_name:,
        action_name:, is_dropdown: true)
    end
    let(:non_dropdown) do
      with_request_url(url) {
        render_inline(described_class.new(organization:, current_user:, controller_namespace:,
          controller_name:, action_name:))
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
      expect(described_class.new(organization: nil, current_user: nil, controller_namespace:,
        controller_name:, action_name:).render?).to be false
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
      let(:controller_name) { "bulk_imports" }

      it "renders the injected bulk imports link with a divider above it" do
        expect(organization.show_bulk_import?).to be false
        items = component.css("li").to_a
        bulk_link_index = items.index { |li| li.css("a.nav-link").text.strip == "Bulk Imports" }
        expect(bulk_link_index).to be > 0
        expect(items[bulk_link_index - 1]["class"].to_s).to include("divider-nav-item")
      end
    end

    context "on a normal page" do
      let(:controller_name) { "registrations" }

      it "does not inject the dashboard or bulk imports link" do
        labels = component.css("a.nav-link").map(&:text).map(&:strip)
        expect(labels).not_to include("#{organization.short_name} dashboard")
        expect(labels).not_to include("Bulk Imports", "Ascend Imports")
      end
    end

    context "as a superuser, with the org lacking the registration_sequences feature" do
      let(:current_user) { FactoryBot.create(:superuser) }

      # The link covers both controllers, so the browser keeps it active while a page of a
      # sequence is being edited
      it "injects a Manage Registration sequences link on the sequences and pages controllers" do
        expect(organization.enabled?("registration_sequences")).to be false
        %w[registration_sequences registration_sequence_pages].each do |sequences_controller|
          rendered = with_request_url(url) {
            render_inline(described_class.new(organization:, current_user:, controller_namespace:,
              controller_name: sequences_controller, action_name:))
          }
          link = rendered.css("a.nav-link").detect { |a| a.text.strip == "Manage Registration sequences" }
          expect(link["data-ui--active-link-routes-value"])
            .to eq "organized/registration_sequences#index organized/registration_sequence_pages"
        end
      end

      it "does not inject it on other pages" do
        expect(component.css("a.nav-link").map { |a| a.text.strip }).not_to include("Manage Registration sequences")
      end
    end
  end
end
