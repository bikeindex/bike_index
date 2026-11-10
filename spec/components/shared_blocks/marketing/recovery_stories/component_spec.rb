# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::RecoveryStories::Component, type: :component do
  let(:recovery_displays) { [FactoryBot.create(:recovery_display_with_photo, quote: "Got it back", quote_by: "Sandy")] }
  let(:component) { render_inline(described_class.new(heading: "Bikes that came home", recovery_displays:)) }

  it "renders the heading, link and stories" do
    expect(component.css("h2").text).to match "Bikes that came home"
    expect(component.css("a[href='/recovery_stories']").count).to eq 1
    expect(component.css("li").text).to match "Got it back"
  end

  context "with no stories" do
    let(:recovery_displays) { RecoveryDisplay.none }

    it "says there are none" do
      expect(component.css("a[href='/recovery_stories']").count).to eq 1
      expect(component.css("ul").count).to eq 0
      expect(component.text).to match "There are no recoveries"
    end
  end
end
