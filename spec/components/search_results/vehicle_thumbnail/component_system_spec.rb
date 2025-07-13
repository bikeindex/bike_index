# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::VehicleThumbnail::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/vehicle_thumbnail/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Humble Frameworks"
  end
end
