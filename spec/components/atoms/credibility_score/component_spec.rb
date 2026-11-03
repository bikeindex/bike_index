# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::CredibilityScore::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:)) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:scorer) { bike.credibility_scorer }

  it "renders the score in its color beside the badges" do
    expect(component).to have_css(".credibility-score[style*='#{CredibilityScorer.color(scorer.score)}']", text: scorer.score.to_s)
    CredibilityScorer.permitted_badges_hash(scorer.badges).each_key do |badge|
      expect(component).to have_css("td", text: CredibilityScorer.humanize_badge(badge))
    end
  end
end
