# frozen_string_literal: true

require "rails_helper"

RSpec.describe DefinitionList::Container::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/definition_list/container/component/default" }

  it "is renders" do
    visit(preview_path)

    expect(page).to have_content "Manufacturer"
  end
end
