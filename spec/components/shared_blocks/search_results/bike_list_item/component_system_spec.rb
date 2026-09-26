# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::SearchResults::BikeListItem::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/shared_blocks/search_results/bike_list_item/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Humble Frameworks"
    expect_axe_clean
  end
end
