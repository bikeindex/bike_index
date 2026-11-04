# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::RecoveryStories::Stories::Component, type: :component do
  let(:component) { render_inline(described_class.new(recovery_displays: [recovery_display], pagy:)) }
  let(:recovery_display) { FactoryBot.create(:recovery_display, quote: "Police called me", quote_by: "Matt", link:) }
  let(:link) { nil }
  let(:pagy) { Pagy::Offset.new(count: 1, page: 1, limit: 9) }

  it "renders the story in the page's frame, with nowhere else to go" do
    expect(component).to have_css("turbo-frame#recovery_stories_page_1 article blockquote", text: "Police called me")
    expect(component).to have_css("article strong", text: "Matt")
    expect(component).to have_no_link("Load more stories")
    expect(component).to have_no_link("Newer stories")
    expect(component).to have_no_css("article a")
  end

  context "with a link and more pages" do
    let(:link) { "https://twitter.com/stolenbikessfo/status/537025628319805443" }
    let(:pagy) { Pagy::Offset.new(count: 20, page: 1, limit: 9) }

    it "links from inside the card and nests the next page's frame in this one" do
      expect(component).to have_css("article a.tw\\:truncate[href='#{link}'][target='_blank'][title='#{link}']", exact_text: "twitter.com/stolenbikessfo/status/5370...")
      expect(component).to have_no_css("a blockquote")
      expect(component).to have_css("turbo-frame#recovery_stories_page_1 > turbo-frame#recovery_stories_page_2 a[data-turbo='true'][data-turbo-action='advance'][href='/recovery_stories?page=2']",
        text: "Load more stories")
    end
  end

  context "on a later page with a custom per_page" do
    let(:pagy) { Pagy::Offset.new(count: 20, page: 2, limit: 4) }

    it "links out of the frame to the newer stories, and carries per_page" do
      expect(component).to have_css("a[data-turbo='false'][href='/recovery_stories?page=1&per_page=4']", text: "Newer stories")
      expect(component).to have_link("Load more stories", href: "/recovery_stories?page=3&per_page=4")
    end
  end
end
