# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ButtonLink::Component, :js, type: :system do
  # Axe reads the same markup whatever the color, so it audits each shape on the first one
  it "tells its four states apart in every color, holds an active color, and can't be followed when disabled" do
    UI::Button::Component::COLORS.each_key.with_index do |color, index|
      # The same four answers a button gives, from an element that only styles like one
      visit "/rails/view_components/ui/button_link/component/#{color}"
      link = find("a[href='#']")
      looks = {resting: state_of(link)}
      hover_then_press(link) { |state| looks[state] = state_of(link) }
      looks[:focus] = state_of(link)

      expect(looks.values.uniq.count).to eq(4), "#{color} repeats a look: #{looks.inspect}"
      expect_axe_clean if index.zero?

      # The same contract the button holds: an active link is already showing its active
      # colors, so only focus and press change anything, and they change the same thing
      visit "/rails/view_components/ui/button_link/component/#{color}_active"
      active = find("a[data-active='true']")
      active_looks = {resting: state_of(active)}
      hover_then_press(active) { |state| active_looks[state] = state_of(active) }
      active_looks[:focus] = state_of(active)

      expect(active_looks[:hover]).to eq(active_looks[:resting]), "#{color} changed on hover"
      expect(active_looks[:focus]).to_not eq(active_looks[:resting]), "#{color} shows nothing on focus"
      expect(active_looks[:press]).to eq(active_looks[:focus]), "#{color} presses differently than it focuses"
      expect(active_looks.values.map(&:first).uniq.count).to eq(1), "#{color} changed color, not just its ring"
      expect_axe_clean if index.zero?

      # An <a> takes no :disabled, so what holds here is the aria-disabled half of each guard
      visit "/rails/view_components/ui/button_link/component/#{color}_disabled"
      disabled = find("a[aria-disabled='true']")
      # The href property reads "" when the attribute is absent and the driver hands back
      # a null as {}, so ask in a form that survives the trip
      expect(disabled.evaluate_script("this.hasAttribute('href') ? 'has href' : 'no href'")).to eq "no href"
      resting = computed_colors(disabled)

      hover_then_press(disabled) do |state|
        expect(computed_colors(disabled)).to eq(resting), "#{color} changed on #{state}"
      end
      expect_axe_clean if index.zero?
    end
  end
end
