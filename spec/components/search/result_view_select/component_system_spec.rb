# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::ResultViewSelect::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/result_view_select/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_css "label", count: 2
    expect(page).to have_css "input[value='bike_box']:checked", visible: :all
    expect_axe_clean

    find("label[title='View as thumbnails']").click
    expect(page).to have_css "input[value='thumbnail']:checked", visible: :all
  end
end
