# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::ReviewAppBanner::Component, type: :component do
  it "doesn't render when review_app is blank" do
    expect(described_class.new(review_app: nil).render?).to be_falsey
    expect(described_class.new(review_app: "").render?).to be_falsey
  end

  context "when review_app is present" do
    let(:component) { render_inline(described_class.new(review_app: "1", pr_number:)) }
    let(:pr_number) { nil }

    it "renders the label and disclaimer" do
      expect(component.text).to include("Review app")
      expect(component.text).to include("not production")
    end

    it "links to the letter_opener inbox" do
      inbox = component.css("a[href='/letter_opener']").first
      expect(inbox).to be_present
      expect(inbox.text).to include("email inbox")
    end

    it "omits the PR link when no pr_number is given" do
      expect(component.css("a[href^='https://github.com']")).to be_empty
    end

    context "with a pr_number" do
      let(:pr_number) { 1234 }

      it "links to the PR on github.com/bikeindex/bike_index" do
        link = component.css("a[href^='https://github.com']").first
        expect(link[:href]).to eq("https://github.com/bikeindex/bike_index/pull/1234")
        expect(link.text).to include("PR #1234")
      end
    end
  end
end
