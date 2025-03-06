# frozen_string_literal: true

require "rails_helper"

RSpec.describe HeaderTags::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/header_tags/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "HeaderTags::Component"
  end
end
