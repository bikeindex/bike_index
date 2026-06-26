# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::TextEditor::Component, :js, type: :system do
  it "upgrades the Lexxy editors and adds and removes them" do
    visit "/rails/view_components/form/text_editor/component/default"

    # The preview seeds two bullets; Lexxy loads lazily and upgrades each
    # <lexxy-editor> by injecting a toolbar -- wait that out on slow CI.
    expect(page).to have_css("lexxy-editor lexxy-toolbar", count: 2, wait: 10)
    expect(page).to have_button("Add feature slug")
    expect_axe_clean

    # Adding appends a fresh editor that the custom element upgrades in turn
    click_button "Add feature slug"

    expect(page).to have_css("lexxy-editor lexxy-toolbar", count: 3)
    expect_axe_clean

    # Removing a bare array entry drops it from the DOM
    first(:button, "Remove").click

    expect(page).to have_css("lexxy-editor lexxy-toolbar", count: 2)
  end
end
