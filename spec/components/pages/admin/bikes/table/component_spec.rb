# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Bikes::Table::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:bike) { FactoryBot.create(:bike, :with_ownership, manufacturer: Manufacturer.other, manufacturer_other: "Cool Bikes") }
  let(:component) do
    with_controller_class(Admin::BikesController) do
      with_request_url("/admin/bikes") { render_inline(described_class.new(bikes: [bike])) }
    end
  end

  it "renders a row for each bike" do
    expect(component).to have_css("td", text: "Cool Bikes")
    expect(component).to have_css("td", text: bike.owner_email)
  end
end
