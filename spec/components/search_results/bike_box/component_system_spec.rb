# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::BikeBox::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/bike_box/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "XXX999 999XXXX"
  end
end
