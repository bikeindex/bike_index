# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::RecoveryDisplayCard::Component, type: :component do
  let(:component) { render_inline(described_class.new(recovery_display:)) }
  let(:recovery_display) { FactoryBot.create(:recovery_display_with_photo, quote: "Got it back", quote_by: "Sandy", link:) }
  let(:link) { nil }

  it "renders the quote and who said it" do
    expect(component).to have_css("li.tw\\:flex blockquote", text: "Got it back")
    expect(component).to have_css("strong", text: "Sandy")
    expect(component).to have_text("Recovered")
    expect(component).to have_css("img[loading='lazy']")
    expect(component).to have_no_css("a")
    expect(component).to have_css("[data-controller='atoms--recovery-display-card'][data-atoms--recovery-display-card-locale-value='en'] blockquote[data-atoms--recovery-display-card-target='quote']")
    expect(component).to have_css("span[data-atoms--recovery-display-card-target='credit'][hidden]", text: "translated from English", visible: :all)
  end

  context "with a link" do
    let(:link) { "https://twitter.com/stolenbikessfo/status/537025628319805443" }

    it "links from inside the card, showing the truncated address" do
      expect(component).to have_css("a.tw\\:truncate[href='#{link}'][target='_blank'][title='#{link}']", exact_text: "twitter.com/stolenbikessfo/status/5370...")
      expect(component).to have_no_css("a blockquote")
    end
  end

  context "without a photo" do
    let(:recovery_display) { FactoryBot.create(:recovery_display, quote: "Got it back") }

    it "keeps the photo's space" do
      expect(component).to have_no_css("img")
      expect(component).to have_css("li > div.tw\\:h-45")
      expect(component).to have_css("blockquote", text: "Got it back")
    end
  end
end
