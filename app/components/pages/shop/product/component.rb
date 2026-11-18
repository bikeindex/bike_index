# frozen_string_literal: true

module Pages
  module Shop
    module Product
      # One product's full-width section, with a link out to its page on the Shopify store.
      # flip puts the media on the right once the row is two columns
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

        # 696px: two of twwiderow's 320px columns and this row's 56px gap
        def media_classes = ["tw:relative", ("tw:@min-[696px]/twwiderow:order-2" if @flip)]
      end
    end
  end
end
