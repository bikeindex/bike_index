# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::HomepageTop::Component, :js, type: :system do
  let(:preview_path) { "rails/view_components/page_block/homepage_top/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "PageBlock::HomepageTop::Component"
  end
end
