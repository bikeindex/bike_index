# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeSearchForm::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/bike_search_form/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "BikeSearchForm::Component"
  end
end
