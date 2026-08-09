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

  # Every color at once: the hovers are guarded not-disabled:, the is-active variant
  # (what :active triggers) excludes disabled, and link color's hover/pressed come from
  # .twlink instead — three mechanisms that each have to hold for a disabled button to
  # look disabled.
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

  # Pointing at a button and pressing it are different answers to give, so a color whose
  # :active look repeats its hover leaves a press looking like nothing happened.
  it "answers hover and press differently, in every color" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button/component/#{color}"
      button = find("button")
      looks = {resting: computed_colors(button)}
      hover_then_press(button) { |state| looks[state] = computed_colors(button) }

      expect(looks.values.uniq.count).to eq(3), "#{color} repeats a look: #{looks.inspect}"
    end
  end
end
