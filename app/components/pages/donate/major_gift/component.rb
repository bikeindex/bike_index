# frozen_string_literal: true

module Pages
  module Donate
    module MajorGift
      # A larger-gift tile. The donate--page controller fills the amount into the form and scrolls to it;
      # without it the link carries the amount to the page's own form
      class Component < ApplicationComponent
        # The first is the Partner tier, the second Benefactor
        AMOUNTS = [500, 1000].freeze

        def initialize(amount:, href:, display:, active: false, html_class: nil)
          @amount = amount
          @href = href
          @display = display
          @active = active
          @html_class = html_class
        end

        private

        def label = (@amount == AMOUNTS.first) ? translation(".partner") : translation(".benefactor")
      end
    end
  end
end
