# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::StepFinished::Component, type: :component do
  let(:component) { render_inline(described_class.new(b_param:, current_user: nil)) }
  let(:b_param) { FactoryBot.create(:b_param, params: {bike: bike_params}) }
  let(:bike_params) { {owner_email: "someone@bikeindex.org", cycle_type: "e-scooter"} }

  it "registers another without an organization" do
    expect(component).to have_link("Register another e-scooter", href: "/register/new")
  end

  context "registered with an organization" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let(:bike_params) { super().merge(creation_organization_id: organization.id) }

    it "carries the organization onto the next registration" do
      expect(component).to have_link("Register another e-scooter",
        href: "/register/new?organization_id=#{organization.slug}")
    end
  end
end
