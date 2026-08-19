# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::OrganizationMenu::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:organization) { FactoryBot.create(:organization, short_name: "Sweet") }
  let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }
  let(:page) { {controller_namespace: nil, controller_name: "welcome", action_name: "index"} }
  let(:instance) { described_class.new(organization:, current_user:, **page) }
  let(:component) { with_request_url("/") { render_inline(instance) } }

  it "renders the organization's dropdown" do
    expect(component).to have_css "#passive_organization_submenu", text: "Sweet"
    expect(component.css(".current-organization-submenu a").map { |link| link.text.strip })
      .to include("Sweet Bikes")
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
