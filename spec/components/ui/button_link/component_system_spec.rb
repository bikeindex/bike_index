# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ButtonLink::Component, :js, type: :system do
  # An <a> takes no :disabled, so what holds here is the aria-disabled half of each guard
  it "holds every disabled color through hover and press, and can't be followed" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button_link/component/#{color}_disabled"
      link = find("a[aria-disabled='true']")
      # The href property reads "" when the attribute is absent and the driver hands back
      # a null as {}, so ask in a form that survives the trip
      expect(link.evaluate_script("this.hasAttribute('href') ? 'has href' : 'no href'")).to eq "no href"
      resting = computed_colors(link)

      hover_then_press(link) do |state|
        expect(computed_colors(link)).to eq(resting), "#{color} changed on #{state}"
      end
    end

    expect_axe_clean
  end

  # The same contract the button holds: an active link is already showing its active
  # colors, so only focus and press change anything, and they change the same thing
  it "leaves an active color alone on hover, and rings the same for focus and press" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button_link/component/#{color}_active"
      link = find("a[data-active='true']")
      looks = {resting: state_of(link)}
      hover_then_press(link) { |state| looks[state] = state_of(link) }
      looks[:focus] = state_of(link)

      expect(looks[:hover]).to eq(looks[:resting]), "#{color} changed on hover"
      expect(looks[:focus]).to_not eq(looks[:resting]), "#{color} shows nothing on focus"
      expect(looks[:press]).to eq(looks[:focus]), "#{color} presses differently than it focuses"
      expect(looks.values.map(&:first).uniq.count).to eq(1), "#{color} changed color, not just its ring"
    end
  end

  # The same four answers a button gives, from an element that only styles like one
  it "looks different resting, hovered, focused and pressed, in every color" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button_link/component/#{color}"
      link = find("a[href='#']")
      looks = {resting: state_of(link)}
      hover_then_press(link) { |state| looks[state] = state_of(link) }
      looks[:focus] = state_of(link)

      expect(looks.values.uniq.count).to eq(4), "#{color} repeats a look: #{looks.inspect}"
    end
  end
end
