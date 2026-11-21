# frozen_string_literal: true

module Pages
  module Donate
    module PhotoWall
      # The strip of recovered bikes across the top of a donate page. short: the desktop row is less tall
      class Component < ApplicationComponent
        # Hand-picked recovery story photos that show the whole bike - the newest story
        # photos are as often a serial sticker or a selfie
        PHOTOS = %w[
          zifmz9ievoovtx971osxccoexyw3 yato0hk1laa4us6otl49uyzldoqu aq90e5l3o00eacqqnkw38k0fyk1h
          gfpgif7uxjy2y7rh11n36uzbfxdd owvsv1dvbn2ljtwglyebih6vwyce xfgqrcjh7ejblp6cffy77a85gotg
          eslpqitkldruibfba8uwt8j0x63v
        ].map { "https://uploads.bikeindex.org/#{it}" }.freeze

        def initialize(short: false)
          @short = short
        end
      end
    end
  end
end
