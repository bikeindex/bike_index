# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Bikes::Table::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership, manufacturer: Manufacturer.other, manufacturer_other: "Cool Bikes") }
  let(:cached_record) { bike }
  let(:component) do
    with_controller_class(Admin::BikesController) do
      with_request_url("/admin/bikes") { render_inline(described_class.new(bikes: [bike])) }
    end
  end

  it "renders a row for each bike, and the panel's time columns under their short headers" do
    expect(component).to have_css("td", text: "Cool Bikes")
    expect(component).to have_css("td", text: bike.owner_email)
    expect(component).to have_css("th.tw\\:sticky", text: "Registered")
    expect(component).to have_field("Time - Registered", checked: true, disabled: true)
    expect(component).to have_css("th.occurred_at_cell", text: "Status at")
    expect(component).to have_field("Time - Status when stolen, impounded, etc")
    expect(component).to have_css("input[value='source_cell'][data-default='false']")
    expect(component).to have_css("input[value='created_by_cell'][data-default='true']")
  end

  it_behaves_like "cached_table_rows"
end
