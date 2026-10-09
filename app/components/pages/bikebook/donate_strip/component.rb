# frozen_string_literal: true

module Pages
  module Bikebook
    module DonateStrip
      class Component < ApplicationComponent
        def render?
          # Written by app/javascript/controllers/bikebook/donate_strip_controller.js
          request.cookies["bikebook_donate_dismissed"].blank?
        end
      end
    end
  end
end
