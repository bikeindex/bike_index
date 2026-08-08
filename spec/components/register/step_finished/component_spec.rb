# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::StepFinished::Component, type: :component do
  let(:component) { render_inline(described_class.new(b_param:, current_user: nil)) }
  let(:b_param) { FactoryBot.create(:b_param, params: {bike: bike_params}) }
  let(:bike_params) { {owner_email: "someone@bikeindex.org", cycle_type: "e-scooter"} }

  it "registers another without an organization, and doesn't offer impound details" do
    expect(component).to have_link("Register another vehicle", href: "/register/new")
    expect(component).to have_no_text("Add details about where you found")
  end

  %w[status_impounded status_abandoned unregistered_parking_notification].each do |status|
    context status do
      let(:bike_params) { super().merge(status:) }

      it "offers to add where it was found" do
        expect(component).to have_text("Add details about where you found the e-scooter")
      end
    end
  end

  context "registered with an organization" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let(:bike_params) { super().merge(creation_organization_id: organization.id) }

    it "carries the organization onto the next registration" do
      expect(component).to have_link("Register another vehicle",
        href: "/register/new?organization_id=#{organization.slug}")
    end
  end
end
