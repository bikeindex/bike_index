# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeSearch::Component, :js, type: :system do
  let(:preview_path) { "rails/view_components/org/bike_search/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Org::BikeSearch::Component"
  end
end
