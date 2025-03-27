# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Form::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/form/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Search::Form::Component"
  end
end
