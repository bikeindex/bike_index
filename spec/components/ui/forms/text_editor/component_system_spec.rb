# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::TextEditor::Component, :js, type: :system do
  # The set the user can actually reach, so a button the gem renames or adds shows up here rather
  # than leaking into the UI behind an assertion that no longer matches anything.
  def visible_toolbar_buttons
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("lexxy-toolbar [name]"))
        .filter((element) => element.offsetParent)
        .map((element) => element.getAttribute("name"))
    JS
  end

  it "upgrades the default Lexxy editor, offers every button, accepts input, and is accessible" do
    visit "/rails/view_components/ui/forms/text_editor/component/default"

    # Lexxy loads lazily and upgrades the <lexxy-editor> by injecting a toolbar -- wait that out.
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)
    expect(page).to_not have_css("lexxy-editor.lexxy-editor--compact")
    expect_axe_clean

    # Nothing is trimmed here, so this pins TOOLBAR_BUTTONS to the gem's actual toolbar -- it fails
    # on the next bump that renames or adds one, instead of silently going stale.
    expected = described_class::TOOLBAR_BUTTONS.map { |button| button.to_s.tr("_", "-") }
    expect(visible_toolbar_buttons).to match_array(expected)

    # The editor is a real contenteditable text box
    editor = find("lexxy-editor [contenteditable='true']")
    editor.click
    editor.send_keys(" and then some")

    expect(editor).to have_text("A rich-text description and then some")
  end

  it "shows only the buttons passed to toolbar_buttons:, and keeps the rest hidden through overflow" do
    visit "/rails/view_components/ui/forms/text_editor/component/custom_toolbar"

    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)
    expect_axe_clean

    expect(visible_toolbar_buttons).to match_array(%w[bold italic link undo redo])

    # A narrow editor makes the gem sweep trailing <button>s into the "..." menu. Constrain the
    # editor, not the window -- headless Chrome floors the window at 500px, too wide to overflow.
    page.execute_script("document.querySelector('lexxy-editor').style.maxWidth = '140px'")
    expect(page).to have_css("lexxy-toolbar[overflowing]", wait: 5)
    find("[aria-label='Show more toolbar buttons']").click

    # table relocates into the open menu; a child-combinator rule would stop hiding it there.
    expect(page).to have_css(".lexxy-editor__toolbar-overflow-menu [name='table']", visible: :all)
    expect(visible_toolbar_buttons).to_not include("table")
  end

  it "applies the size-scoped overrides to the compact variant (size: :single_line)" do
    visit "/rails/view_components/ui/forms/text_editor/component/single_line"

    expect(page).to have_css("lexxy-editor.lexxy-editor--compact lexxy-toolbar", wait: 10)
    expect_axe_clean

    # The compact override sets a custom property only on .lexxy-editor--compact
    rows = page.evaluate_script("getComputedStyle(document.querySelector('lexxy-editor')).getPropertyValue('--lexxy-editor-rows').trim()")
    expect(rows).to eq("1.4em")
  end
end
