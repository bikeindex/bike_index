# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::RecoveryStories::Index::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) do
    {recovery_displays:, pagy:, total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345,
     organizations_count: 1_000, currency: Currency.default}
  end
  let(:recovery_displays) { [recovery_display] }
  let(:recovery_display) { FactoryBot.create(:recovery_display, quote: "Police called me", quote_by: "Matt", link:) }
  let(:link) { nil }
  let(:pagy) { Pagy::Offset.new(count: 1, page: 1, limit: 9) }

  it "renders the stats, the stories and the gift picker" do
    expect(component).to have_css("h1", text: "Every one of these bikes found its way home.")
    expect(component).to have_text("1M+")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38M+")
    expect(component).to have_text("1,000+")
    expect(component).to have_css("article blockquote", text: "Police called me")
    expect(component).to have_css("article strong", text: "Matt")
    expect(component).to_not have_link("Load more stories")

    expect(component).to have_css("form#gift_monthly[action='/membership/new'][method='get']")
    expect(component).to have_checked_field("gift_monthly_plus", visible: :all)
    expect(component).to have_css("#gift_monthly input[name='referral_source'][value='recovery-stories']", visible: :all)
    expect(component).to have_button("Become a member · $15/month")
    expect(component).to have_text("$5")
    expect(component).to have_text("$50")
    expect(component).to have_css("form#gift_one_time[action='/donate'][method='get']")
    expect(component).to have_checked_field("gift_one_time_50", visible: :all)
    expect(component).to have_button("Donate $50")
  end

  context "with a link and more pages" do
    let(:link) { "https://bikeindex.org/news/matt" }
    let(:pagy) { Pagy::Offset.new(count: 20, page: 1, limit: 9) }

    it "links the card and nests the next page's frame in this one" do
      expect(component).to have_css("a[href='#{link}'] blockquote", text: "Police called me")
      expect(component).to have_css("turbo-frame#recovery_stories_page_1 > turbo-frame#recovery_stories_page_2 a[data-turbo='true'][href='/recovery_stories?page=2']",
        text: "Load more stories")
    end
  end
end
