# frozen_string_literal: true

module Pages
  module Shop
    module Index
      # The merchandise sold on the Shopify store. Each product links to its page there, where the
      # customer picks options and checks out, so there is no cart - and the prices are copy that
      # has to be kept in step with the store
      class Component < ApplicationComponent
        # Template Dependency: SharedBlocks::Marketing::Wrapper::Component
        STORE_URL = "https://bikeindex.myshopify.com/products"
        FIRST_PRODUCT_ID = "caped-registrant-cap"
        STICKERS_ID = "registration-stickers"
        PRICES = {caped_cap: "$20.00", cycling_cap: "$15.00", sticker: "$7.99"}.freeze

        BURST_CLASSES = "tw:absolute tw:font-header tw:font-extrabold tw:text-[44px] tw:tracking-[.02em] " \
          "tw:[-webkit-text-stroke:2px_#000]"

        private

        def product_url(handle) = "#{STORE_URL}/#{handle}"
      end
    end
  end
end
