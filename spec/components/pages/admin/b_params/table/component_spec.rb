# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::BParams::Table::Component, type: :component do
  let(:component) do
    with_request_url("/admin/b_params") do
      render_inline(described_class.new(b_params: [b_param],
        sort_state: ComponentStructs::SortState.new(search_params: {period: "all"})))
    end
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:b_param) { FactoryBot.create(:b_param_with_creation_organization, organization:, origin: "embed_partial") }

  it "renders the b_param's links, origin and params" do
    expect(component).to have_css("a[href='/admin/b_params/#{b_param.id}']")
    expect(component).to have_css("a[href='/admin/users/#{b_param.creator_id}']")
    expect(component).to have_css("a[href='/admin/organizations/#{organization.id}']")
    expect(component).to have_css("a[href*='organization_id=#{organization.id}']")
    expect(component.text).to include "Embed partial"
    expect(component.text).to include b_param.email
    expect(component.text).to include "owner_email"
  end

  context "with bike_errors and a created bike" do
    let(:bike) { FactoryBot.create(:bike) }

    before { b_param.update(bike_errors: ["frame_material is not valid"], created_bike_id: bike.id) }

    it "renders the errors humanized and links the bike" do
      expect(component.text).to include "Frame material is not valid"
      expect(component).to have_css("a[href='/admin/bikes/#{bike.id}']")
    end
  end
end
