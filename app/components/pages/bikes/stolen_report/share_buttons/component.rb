# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module ShareButtons
        # Facebook, Nextdoor when there's something to tell the neighbors, and copying the link.
        # The block renders after them
        class Component < ApplicationComponent
          def initialize(url:, nextdoor_text: nil)
            @url = url
            @nextdoor_text = nextdoor_text
          end

          private

          def facebook_url = "https://www.facebook.com/sharer/sharer.php?#{{u: @url}.to_query}"

          def nextdoor_url = "https://nextdoor.com/sharekit/?#{{source: "bikeindex", body: "#{@nextdoor_text} #{@url}"}.to_query}"
        end
      end
    end
  end
end
