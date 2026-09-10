# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::SearchResults::VehicleThumbnail::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/search_results/vehicle_thumbnail/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Humble Frameworks"
    expect_axe_clean
  end
end
