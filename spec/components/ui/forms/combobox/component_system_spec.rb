# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Combobox::Component, :js, type: :system do
  it "opens, filters, selects, and closes" do
    visit "/rails/view_components/ui/forms/combobox/component/default"

    # `aria-expanded` is set by the combobox Stimulus controller on connect, not
    # in the server-rendered HTML -- wait out the first JS connect on slow CI.
    expect(page).to have_css('[aria-expanded="false"]', wait: 10)
    expect_axe_clean

    # Opens the listbox on click
    find_field("Cycle type").click

    expect(page).to have_css('[aria-expanded="true"]')
    expect(page).to have_css('[role="option"]', count: CycleType.slugs.count)
    expect_axe_clean

    # Filters the options as you type
    fill_in "Cycle type", with: "cargo"

    expect(page).to have_css('[role="option"]', text: "Cargo Bike (front storage)")
    expect(page).to have_css('[role="option"]', text: "Cargo Tricycle (trike with rear storage)")
    expect(page).not_to have_css('[role="option"]', text: "Unicycle")

    # Selecting an option closes the listbox and fills the visible input
    # and the hidden field that carries the form value
    find('[role="option"]', text: "Cargo Bike (front storage)").click

    expect(page).to have_css('[aria-expanded="false"]')
    expect(find_field("Cycle type").value).to eq "Cargo Bike (front storage)"
    expect(find("input[name='cycle_type']", visible: :hidden).value).to eq "Cargo Bike (front storage)"

    # Reopen, then close with the Escape key
    find_field("Cycle type").click

    expect(page).to have_css('[aria-expanded="true"]')

    send_keys(:escape)

    expect(page).to have_css('[aria-expanded="false"]')
  end

  context "with a selection already made" do
    it "keeps the selection under an arrow key, and replaces it whole when typing" do
      visit "/rails/view_components/ui/forms/combobox/component/default"

      expect(page).to have_css('[aria-expanded="false"]', wait: 10)

      find_field("Cycle type").click
      find('[role="option"]', text: "Unicycle", exact_text: true).click

      expect(find_field("Cycle type").value).to eq "Unicycle"

      # ArrowUp doesn't open a closed listbox, so it used to pick out of an empty one and
      # throw -- past the deselect that starts a selection, which had emptied the field
      find_field("Cycle type").send_keys(:up)

      expect(find_field("Cycle type").value).to eq "Unicycle"
      expect(find("input[name='cycle_type']", visible: :hidden).value).to eq "Unicycle"

      # Typing used to insert wherever the click left the caret, mangling the display into
      # a query matching no option -- which cleared the hidden field. Clicking in selects
      # the display now, so the first keystroke replaces it.
      find_field("Cycle type").click
      send_keys("tand")

      expect(find_field("Cycle type").value).to eq "Tandem"
      expect(find("input[name='cycle_type']", visible: :hidden).value).to eq "Tandem"
    end
  end

  context "inside a form" do
    it "submits on enter once the listbox is closed" do
      visit "/rails/view_components/ui/forms/combobox/component/in_form"

      expect(page).to have_css('[aria-expanded="false"]', wait: 10)

      # Enter while picking belongs to the combobox, and only closes it
      find_field("Cycle type").click
      fill_in "Cycle type", with: "unicycle"
      send_keys(:enter)

      expect(page).to have_css('[aria-expanded="false"]')
      expect(page).to have_current_path("/rails/view_components/ui/forms/combobox/component/in_form")

      send_keys(:enter)

      expect(page).to have_current_path(/cycle_type=Unicycle/)
    end
  end

  context "with rich_display" do
    let(:overlay) { "[data-ui--forms--combobox-display-target='overlay']" }

    it "mirrors the selected option's two-tone content onto the closed input" do
      visit "/rails/view_components/ui/forms/combobox/component/rich_display"

      # Nothing selected yet, so there is no rich content to mirror
      expect(page).to have_css('[aria-expanded="false"]', wait: 10)
      expect(page).to have_no_css(overlay)

      find_field("Cycle type").click
      find('[role="option"]', text: "Cargo Bike (front storage)").click

      expect(page).to have_css(overlay, text: "Cargo Bike (front storage)")
      expect(page).to have_css("#{overlay} span", text: "(front storage)")

      # Clicking in doesn't blank the display -- only typing a query does
      find_field("Cycle type").click

      expect(page).to have_css(overlay, text: "Cargo Bike (front storage)")

      fill_in "Cycle type", with: "uni"

      expect(page).to have_no_css(overlay)

      # The handle clears the selection without any event of its own
      find('[role="option"]', text: "Unicycle", exact_text: true).click

      expect(page).to have_css(overlay, text: "Unicycle")

      find(".hw-combobox__handle").click

      expect(page).to have_no_css(overlay)
    end
  end

  context "inside a form-persist form" do
    # The combobox always renders with a selection, so there is no empty state
    # for form-persist to fill -- the draft has to win over the rendered value
    it "restores the draft selection" do
      visit "/rails/view_components/ui/forms/combobox/component/persisted"

      expect(page).to have_css('[aria-expanded="false"]', wait: 10)
      expect(find_field("Cycle type").value).to eq "Bike"

      find_field("Cycle type").click
      find('[role="option"]', text: "Unicycle", exact_text: true).click

      visit "/rails/view_components/ui/forms/combobox/component/persisted"

      expect(find_field("Cycle type").value).to eq "Unicycle"
      expect(find("input[name='cycle_type']", visible: :hidden).value).to eq "unicycle"
    end
  end

  context "with rich_display: :stacked" do
    let(:overlay) { "[data-ui--forms--combobox-display-target='overlay']" }

    it "mirrors both lines onto the taller input" do
      visit "/rails/view_components/ui/forms/combobox/component/stacked"

      expect(page).to have_css('[aria-expanded="false"]', wait: 10)

      find_field("Registration type").click
      find('[role="option"]', text: "It was stolen").click

      expect(page).to have_css("#{overlay} span", text: "It was stolen")
      expect(page).to have_css("#{overlay} span", text: "Report a bike stolen so others can help find it")
    end

    # The gem swaps to a full screen dialog below its mobile breakpoint, and
    # selecting there fills the input after the selection event, never focusing it
    it "mirrors a selection made in the small viewport dialog, and always unlocks the page" do
      emulate_ios_platform
      page.current_window.resize_to(390, 844)
      visit "/rails/view_components/ui/forms/combobox/component/stacked"

      expect(page).to have_css('[aria-expanded="false"]', wait: 10)

      find_field("Registration type").click

      expect(page).to have_css("dialog[open]")
      expect(page).to have_css(scroll_locked_body)
      expect(touch_scroll_blocked?).to be true

      # Type a query that matches nothing, so dismissing has something to clean up
      type_into(".hw-combobox__dialog__input", "zzz")

      # Android's back gesture closes the dialog with a close request rather than a
      # keypress, which nothing on the page can synthesize
      page.execute_script("document.querySelector('dialog[open]').close()")

      expect(page).to have_no_css("dialog[open]")
      expect(page).to have_no_css(scroll_locked_body)
      # Where escape lands, the browser having sent the same close request: the query
      # is gone rather than stranded in the field with an empty value behind it
      expect(find_field("Registration type").value).to eq ""
      expect(find("input[name='status']", visible: :hidden).value).to eq ""

      find_field("Registration type").click

      expect(page).to have_css("dialog[open]")

      # iOS's back swipe navigates rather than dismissing, so Turbo discards the dialog
      # without ever closing it - again nothing on the page can synthesize the gesture
      page.execute_script("document.dispatchEvent(new CustomEvent('turbo:before-render'))")

      expect(page).to have_no_css("dialog[open]")
      expect(page).to have_no_css(scroll_locked_body)
      expect(touch_scroll_blocked?).to be false

      find_field("Registration type").click

      expect(page).to have_css("dialog[open]")

      find('[role="option"]', text: "It was stolen").click

      expect(page).to have_no_css("dialog[open]")
      expect(page).to have_no_css(scroll_locked_body)
      expect(page).to have_css("#{overlay} span", text: "It was stolen")

      # Leaving in the same frame the dialog opened in, which is a rider swiping back the
      # instant the picker appears. iOS pins the body from inside its own animation frame,
      # so a release that doesn't wait for it leaves the pin on with nothing left to lift it
      page.execute_script(<<~JS)
        const dialog = document.querySelector(".hw-combobox dialog")
        new MutationObserver((_records, observer) => {
          if (!dialog.open) return
          observer.disconnect()
          document.dispatchEvent(new CustomEvent("turbo:before-render"))
          // The frame the pin lands in, so the assertions below can't run ahead of it
          requestAnimationFrame(() => requestAnimationFrame(() => { window.tornDownMidFrame = true }))
        }).observe(dialog, {attributes: true, attributeFilter: ["open"]})
        document.querySelector(".hw-combobox__input").click()
      JS
      wait_for { page.evaluate_script("window.tornDownMidFrame") }

      expect(page).to have_no_css("dialog[open]")
      expect(page).to have_no_css(scroll_locked_body)
      expect(touch_scroll_blocked?).to be false
    end
  end
end
