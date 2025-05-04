# frozen_string_literal: true

require "rails_helper"

RSpec.describe DefinitionList::Row::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/definition_list/row/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "DefinitionList::Row::Component"
  end
end
