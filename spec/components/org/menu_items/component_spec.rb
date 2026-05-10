# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::MenuItems::Component, type: :component do
  let(:instance) { described_class.new(organization:, current_user:) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/dashboard") { render_inline(instance) }
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  it "renders nav links, dividers, and disabled placeholders for a member of a basic org" do
    expect(instance.render?).to be true
    expect(component.css("li").length).to be > 0
    expect(component.css("a.nav-link").map(&:text).map(&:strip)).to include(
      "#{organization.short_name} Bikes", "Add a bike"
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
    context "on the dashboard with overview_dashboard? off" do
      let(:component) do
        with_request_url("/o/#{organization.to_param}/dashboard") { render_inline(instance) }
      end

      it "still renders the dashboard link so the active page is represented" do
        expect(organization.overview_dashboard?).to be false
        labels = component.css("a.nav-link").map(&:text).map(&:strip)
        expect(labels).to include("#{organization.short_name} dashboard")
      end
    end

    context "on bulk_imports without show_bulk_import?" do
      let(:component) do
        with_request_url("/o/#{organization.to_param}/bulk_imports") { render_inline(instance) }
      end

      it "still renders the bulk imports link" do
        expect(organization.show_bulk_import?).to be false
        labels = component.css("a.nav-link").map(&:text).map(&:strip)
        expect(labels).to include("Bulk Imports")
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
  end
end
