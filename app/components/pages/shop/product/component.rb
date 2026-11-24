# frozen_string_literal: true

module Pages
  module Shop
    module Product
      # One product's full-width section, with a link out to its page on the Shopify store.
      # flip puts the media on the right once the row is two columns
      class Component < ApplicationComponent
        # Template Dependency: SharedBlocks::Marketing::Wrapper::Component
        renders_one :media
        renders_one :pricing
        renders_one :note

        def initialize(name:, category:, description:, url:, price: nil, flip: false, band: false, id: nil)
          @name = name
          @price = price
          @category = category
          @description = description
          @url = url
          @flip = flip
          @band = band
          @id = id
        end

        private

        # 696px: two of twwiderow's 320px columns and this row's 56px gap
        def media_classes = ("tw:@min-[696px]/twwiderow:order-2" if @flip)
      end
    end
  end
end
