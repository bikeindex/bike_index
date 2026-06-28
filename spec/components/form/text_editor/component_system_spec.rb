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

  it "shows only the buttons passed to toolbar_buttons: and hides the rest" do
    visit "/rails/view_components/form/text_editor/component/custom_toolbar"

    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)
    expect_axe_clean

    # toolbar_buttons: %i[bold italic link undo redo] -- only these are visible
    expect(page).to have_css("lexxy-toolbar button[name='bold']")
    expect(page).to have_css("lexxy-toolbar button[name='italic']")
    expect(page).to have_css("lexxy-toolbar summary[name='link']")
    expect(page).to have_css("lexxy-toolbar button[name='undo']")
    expect(page).to have_css("lexxy-toolbar button[name='redo']")

    # the omitted buttons are hidden (present in the DOM, but display: none)
    expect(page).to have_no_css("lexxy-toolbar button[name='strikethrough']")
    expect(page).to have_no_css("lexxy-toolbar button[name='heading']")
    expect(page).to have_no_css("lexxy-toolbar button[name='code']")
    expect(page).to have_no_css("lexxy-toolbar button[name='table']")
    expect(page).to have_no_css("lexxy-toolbar summary[name='highlight']")
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
