# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::TextEditor::Component, :js, type: :system do
  it "upgrades the Lexxy editor, accepts input, and is accessible" do
    visit "/rails/view_components/form/text_editor/component/default"

    # Lexxy loads lazily and upgrades the <lexxy-editor> by injecting a toolbar -- wait that out.
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)
    expect_axe_clean

    # The editor is a real contenteditable text box
    editor = find("lexxy-editor [contenteditable='true']")
    editor.click
    editor.send_keys(" and then some")

    expect(editor).to have_text("A rich-text description and then some")
  end
end
