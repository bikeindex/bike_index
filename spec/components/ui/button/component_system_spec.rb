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

  # Three mechanisms have to hold for this: the guarded hovers, the is-active variant,
  # and .twlink, which is where link color's hover and pressed come from
  it "holds every disabled color through hover and press" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button/component/#{color}_disabled"
      button = find("button[disabled]")
      resting = computed_colors(button)

      hover_then_press(button) do |state|
        expect(computed_colors(button)).to eq(resting), "#{color} changed on #{state}"
      end
    end
  end

  # It's already wearing its active colors, so hover has nothing to add and :active has
  # no color left to change — both focus and press just widen the ring
  it "leaves an active color alone on hover, and rings the same for focus and press" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button/component/#{color}_active"
      button = find("button[data-active='true']")
      looks = {resting: state_of(button)}
      hover_then_press(button) { |state| looks[state] = state_of(button) }
      # The press left it focused, with the pointer moved away
      looks[:focus] = state_of(button)

      expect(looks[:hover]).to eq(looks[:resting]), "#{color} changed on hover"
      expect(looks[:focus]).to_not eq(looks[:resting]), "#{color} shows nothing on focus"
      expect(looks[:press]).to eq(looks[:focus]), "#{color} presses differently than it focuses"
      expect(looks.values.map(&:first).uniq.count).to eq(1), "#{color} changed color, not just its ring"
    end
  end

  # Four things a button can be doing, four looks — a color that repeats one leaves a
  # rider unable to tell which of them just happened
  it "looks different resting, hovered, focused and pressed, in every color" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button/component/#{color}"
      button = find("button")
      looks = {resting: state_of(button)}
      hover_then_press(button) { |state| looks[state] = state_of(button) }
      # The press left it focused, with the pointer moved away
      looks[:focus] = state_of(button)

      expect(looks.values.uniq.count).to eq(4), "#{color} repeats a look: #{looks.inspect}"
    end
  end
end
