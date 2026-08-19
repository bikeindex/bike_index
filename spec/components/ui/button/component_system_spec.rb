# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Button::Component, :js, type: :system do
  let(:spinner) { "[data-ui--button--submit-spinner-target='spinner']" }

  it "reveals the spinner once the form submits, and not before" do
    visit "/rails/view_components/ui/button/component/in_form"

    expect(page).to have_button("Next", wait: 10)
    expect(page).to have_no_css(spinner)
    expect_axe_clean

    # Native validation rejects the empty email, so the form never submits
    click_button "Next"

    expect(page).to have_button("Next")
    expect(page).to have_no_css(spinner)

    fill_in "Email", with: "user@bikeindex.org"
    click_button "Next"

    expect(page).to have_css(spinner)
    expect(page).to have_button("Next", disabled: true)
    expect_axe_clean
  end

  # Axe reads the same markup whatever the color, so it audits each shape on the first one
  it "tells its four states apart in every color, holds an active color, and freezes when disabled" do
    UI::Button::Component::COLORS.each_key.with_index do |color, index|
      # Four things a button can be doing, four looks — a color that repeats one leaves a
      # rider unable to tell which of them just happened
      visit "/rails/view_components/ui/button/component/#{color}"
      button = find("button")
      looks = {resting: state_of(button)}
      hover_then_press(button) { |state| looks[state] = state_of(button) }
      # The press left it focused, with the pointer moved away
      looks[:focus] = state_of(button)

      expect(looks.values.uniq.count).to eq(4), "#{color} repeats a look: #{looks.inspect}"
      expect_axe_clean if index.zero?

      # It's already wearing its active colors, so hover has nothing to add and :active has
      # no color left to change — both focus and press just widen the ring
      visit "/rails/view_components/ui/button/component/#{color}_active"
      active = find("button[data-active='true']")
      active_looks = {resting: state_of(active)}
      hover_then_press(active) { |state| active_looks[state] = state_of(active) }
      active_looks[:focus] = state_of(active)

      expect(active_looks[:hover]).to eq(active_looks[:resting]), "#{color} changed on hover"
      expect(active_looks[:focus]).to_not eq(active_looks[:resting]), "#{color} shows nothing on focus"
      expect(active_looks[:press]).to eq(active_looks[:focus]), "#{color} presses differently than it focuses"
      expect(active_looks.values.map(&:first).uniq.count).to eq(1), "#{color} changed color, not just its ring"
      expect_axe_clean if index.zero?

      # Three mechanisms have to hold for this: the guarded hovers, the is-active variant,
      # and .twlink, which is where link color's hover and pressed come from
      visit "/rails/view_components/ui/button/component/#{color}_disabled"
      disabled = find("button[disabled]")
      resting = computed_colors(disabled)

      hover_then_press(disabled) do |state|
        expect(computed_colors(disabled)).to eq(resting), "#{color} changed on #{state}"
      end
      expect_axe_clean if index.zero?
    end
  end
end
