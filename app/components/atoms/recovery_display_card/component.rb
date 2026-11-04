# frozen_string_literal: true

module Atoms
  module RecoveryDisplayCard
    # A recovery story as a photo card, the <li> of a list of them
    class Component < ApplicationComponent
      def initialize(recovery_display:, html_class: "tw:flex")
        @recovery_display = recovery_display
        @html_class = html_class
      end
    end
  end
end
