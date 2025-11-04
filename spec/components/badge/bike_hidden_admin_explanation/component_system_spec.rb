# frozen_string_literal: true

require "rails_helper"

RSpec.describe Badge::BikeHiddenAdminExplanation::Component, :js, type: :system do
  let(:preview_path) { "rails/view_components/badge/bike_hidden_admin_explanation/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Badge::BikeHiddenAdminExplanation::Component"
  end
end
