# frozen_string_literal: true

module Pages
  module Shop
    module Index
      # The merchandise sold on the Shopify store. Each product links to its page there, where the
      # customer picks options and checks out, so there is no cart - and the prices are copy that
      # has to be kept in step with the store
      class Component < ApplicationComponent
        # Template Dependency: Pages::Shop::Product::Component
        STORE_URL = "https://bikeindex.myshopify.com/products"
        FIRST_PRODUCT_ID = "caped-registrant-cap"

        BURST_CLASSES = "tw:absolute tw:font-[Bangers,_cursive] tw:text-[44px] tw:tracking-[.02em] " \
          "tw:[-webkit-text-stroke:2px_#000]"
        PRICE_CLASSES = "tw:m-0 tw:font-header tw:font-extrabold"

        def before_render
          helpers.content_for(:header) do
            tag.link(href: "https://fonts.googleapis.com/css2?family=Bangers&family=Patrick+Hand&display=swap", rel: "stylesheet")
          end
        end

        private

        def product_url(handle) = "#{STORE_URL}/#{handle}"
      end
    end
  end
end
