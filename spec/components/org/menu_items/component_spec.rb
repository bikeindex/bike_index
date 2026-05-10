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

  context "with no organization" do
    it "does not render" do
      expect(described_class.new(organization: nil, current_user: nil).render?).to be false
    end
  end

  context "as a superuser" do
    let(:current_user) { FactoryBot.create(:superuser) }

    it "renders the super admin link with the less-strong wrapper" do
      super_admin = component.css("li.less-strong a").map(&:text).map(&:strip)
      expect(super_admin).to include("Super Admin for #{organization.short_name}")
    end
  end

  context "with bike_stickers disabled and not a dropdown" do
    it "renders a disabled placeholder for registration stickers" do
      disabled = component.css("span.disabled-menu-item").map(&:text).map(&:strip)
      expect(disabled).to include("Registration stickers")
    end
  end

  context "is_dropdown: true with bike_stickers disabled" do
    let(:instance) { described_class.new(organization:, current_user:, is_dropdown: true) }

    it "does not render a disabled placeholder" do
      expect(component.css("span.disabled-menu-item").map(&:text).map(&:strip)).not_to include("Registration stickers")
    end
  end
end
