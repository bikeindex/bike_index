# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::ResultViewSelect::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/result_view_select/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_css "ul"
  end
end
