# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::MenuItems::Component, type: :component do
  let(:instance) { described_class.new(organization:, current_user:) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/dashboard") { render_inline(instance) }
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  it "renders nav links inside li wrappers" do
    expect(instance.render?).to be true
    expect(component.css("li").length).to be > 0
    expect(component.css("a.nav-link").map(&:text).map(&:strip)).to include(
      "#{organization.short_name} Bikes", "Add a bike"
    )
  end

  it "renders dividers" do
    expect(component.css("li.divider-nav-item").length).to be > 0
  end

  it "renders disabled placeholders in non-dropdown mode" do
    disabled = component.css("span.disabled-menu-item").map(&:text).map(&:strip)
    expect(disabled).to include("Registration stickers")
  end

  context "is_dropdown: true" do
    let(:instance) { described_class.new(organization:, current_user:, is_dropdown: true) }

    it "skips disabled placeholders" do
      expect(component.css("span.disabled-menu-item")).to be_empty
    end

    it "drops the trailing divider for non-superusers" do
      dropdown_dividers = component.css("li.divider-nav-item").length
      non_dropdown = with_request_url("/o/#{organization.to_param}/dashboard") {
        render_inline(described_class.new(organization:, current_user:))
      }
      expect(dropdown_dividers).to be < non_dropdown.css("li.divider-nav-item").length
    end

    context "as a superuser" do
      let(:current_user) { FactoryBot.create(:superuser) }

      it "keeps the trailing divider" do
        dropdown_dividers = component.css("li.divider-nav-item").length
        non_dropdown = with_request_url("/o/#{organization.to_param}/dashboard") {
          render_inline(described_class.new(organization:, current_user:))
        }
        expect(dropdown_dividers).to eq non_dropdown.css("li.divider-nav-item").length
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

  describe "active state resolution" do
    let(:registrations_item) { {type: :link, label: "x", path: "/x", active: :on_registrations_index} }
    let(:bikes_new_item) { {type: :link, label: "y", path: "/y", active: :on_bikes_new} }
    let(:auto_item) { {type: :link, label: "z", path: "/z", active: :auto} }

    it "resolves :on_registrations_index based on the controller" do
      ctrl = double(controller_name: "registrations", action_name: "index")
      allow(instance).to receive(:controller).and_return(ctrl)
      expect(instance.send(:active_state, registrations_item)).to eq true
    end

    it "returns false when not on the matching page" do
      ctrl = double(controller_name: "dashboard", action_name: "index")
      allow(instance).to receive(:controller).and_return(ctrl)
      expect(instance.send(:active_state, registrations_item)).to eq false
      expect(instance.send(:active_state, bikes_new_item)).to eq false
    end

    it "returns nil for :auto so the template defers to active_link" do
      expect(instance.send(:active_state, auto_item)).to be_nil
    end
  end
end
