# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ButtonLink::Component, :js, type: :system do
  # An <a> takes no :disabled, so the guards it holds are the aria-disabled half of
  # each pair — and link color's hover/pressed come from .twlink instead. The link
  # also has no href, so this asserts what "disabled" means for a link either way.
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
      looks = {resting: [computed_colors(link), computed_ring(link)]}
      hover_then_press(link) { |state| looks[state] = [computed_colors(link), computed_ring(link)] }
      looks[:focus] = [computed_colors(link), computed_ring(link)]

      expect(looks[:hover]).to eq(looks[:resting]), "#{color} changed on hover"
      expect(looks[:focus]).to_not eq(looks[:resting]), "#{color} shows nothing on focus"
      expect(looks[:press]).to eq(looks[:focus]), "#{color} presses differently than it focuses"
      expect(looks.values.map(&:first).uniq.count).to eq(1), "#{color} changed color, not just its ring"
    end
  end

  # The same three answers a button gives, from an element that only styles like one
  it "answers hover and press differently, in every color" do
    UI::Button::Component::COLORS.each_key do |color|
      visit "/rails/view_components/ui/button_link/component/#{color}"
      link = find("a[href='#']")
      looks = {resting: computed_colors(link)}
      hover_then_press(link) { |state| looks[state] = computed_colors(link) }

      expect(looks.values.uniq.count).to eq(3), "#{color} repeats a look: #{looks.inspect}"
    end
  end
end
