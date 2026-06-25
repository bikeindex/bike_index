# frozen_string_literal: true

# Read-only renderer for a RegistrationSequence's pages, shared by the org show/preview views
# and the admin review view so the live and upcoming versions render identically.
module RegistrationSequencePreview
  class Component < ApplicationComponent
    def initialize(registration_sequence:)
      @registration_sequence = registration_sequence
    end

    def render?
      @registration_sequence.present?
    end

    def bullet_html(bullet)
      Binxtils::InputNormalizer.sanitize(Kramdown::Document.new(bullet).to_html).html_safe
    end
  end
end
