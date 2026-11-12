# frozen_string_literal: true

module Pages
  module Donate
    module MajorGift
      # A larger-gift tile. The donate--page controller fills the amount into the form and scrolls to it;
      # without it the link carries the amount to the page's own form
      class Component < ApplicationComponent
        def initialize(amount:, label:, href:, display:, active: false, html_class: nil)
          @amount = amount
          @label = label
          @href = href
          @display = display
          @active = active
          @html_class = html_class
        end
      end
    end
  end
end
