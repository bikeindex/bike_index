# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::EverythingCombobox::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_componentssearch/everything_combobox/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Search::EverythingCombobox::Component"
  end
end
