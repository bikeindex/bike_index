# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::RecoveryDisplayCard::Component, type: :component do
  let(:component) { render_inline(described_class.new(recovery_display:)) }
  let(:recovery_display) { FactoryBot.create(:recovery_display_with_photo, quote: "Got it back", quote_by: "Sandy") }

  it "renders the quote and who said it" do
    expect(component).to have_css("li.tw\\:flex blockquote", text: "Got it back")
    expect(component).to have_css("strong", text: "Sandy")
    expect(component).to have_text("Recovered")
    expect(component).to have_css("img[loading='lazy']")
  end
end
