# frozen_string_literal: true

module Atoms
  module CredibilityScore
    # A bike's credibility score, beside the badges that make it up
    class Component < ApplicationComponent
      def initialize(bike:)
        scorer = bike.credibility_scorer
        @score = scorer.score
        @badges = CredibilityScorer.permitted_badges_hash(scorer.badges)
      end
    end
  end
end
