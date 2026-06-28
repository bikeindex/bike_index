# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::TextEditor::Component, :js, type: :system do
  it "upgrades the default Lexxy editor, accepts input, and is accessible" do
    visit "/rails/view_components/form/text_editor/component/default"

    # Lexxy loads lazily and upgrades the <lexxy-editor> by injecting a toolbar -- wait that out.
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)
    expect(page).to_not have_css("lexxy-editor.lexxy-editor--compact")
    expect_axe_clean

    # The editor is a real contenteditable text box
    editor = find("lexxy-editor [contenteditable='true']")
    editor.click
    editor.send_keys(" and then some")

    expect(editor).to have_text("A rich-text description and then some")
  end

  it "applies the size-scoped overrides to the compact variant (size: :single_line)" do
    visit "/rails/view_components/form/text_editor/component/single_line"

    expect(page).to have_css("lexxy-editor.lexxy-editor--compact lexxy-toolbar", wait: 10)
    expect_axe_clean

    # The compact override sets a custom property only on .lexxy-editor--compact
    rows = page.evaluate_script("getComputedStyle(document.querySelector('lexxy-editor')).getPropertyValue('--lexxy-editor-rows').trim()")
    expect(rows).to eq("2.4em")
  end
end
