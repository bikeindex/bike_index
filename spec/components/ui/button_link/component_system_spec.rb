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
end
