# frozen_string_literal: true

module Pages
  module Shop
    module Product
      # One product's full-width section, with a link out to its page on the Shopify store.
      # media: the image side. price: what sits above the link. note: what follows it.
      # flip: media on the right of the text from md up. band: the tinted, ruled background
      class Component < ApplicationComponent
        # Template Dependency: SharedBlocks::Marketing::Wrapper::Component
        BAND_CLASSES = "tw:border-y tw:border-gray-200 tw:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-800/60"

        renders_one :media
        renders_one :price
        renders_one :note

        def initialize(name:, category:, sound:, description:, url:, flip: false, band: false, id: nil)
          @name = name
          @category = category
          @sound = sound
          @description = description
          @url = url
          @flip = flip
          @band = band
          @id = id
        end

        private

        def section_classes = @band ? BAND_CLASSES : nil

        def media_classes = ["tw:relative", ("tw:md:order-2" if @flip)].compact.join(" ")
      end
    end
  end
end
