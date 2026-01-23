# frozen_string_literal: true

module PageBlock::NewSaleForm
  class Component < ApplicationComponent
    def initialize(currency:, sale:, item: nil, marketplace_message: nil)
      @currency = currency
      @sale = sale
      # Assign an amount
      @sale.amount_cents ||= @sale.marketplace_listing&.amount_cents
      @marketplace_message = marketplace_message || @sale.marketplace_message
      @item = item || @marketplace_message&.item
    end

    private

    def item_type
      @item.type
    end

    def buyer_name
      @marketplace_message.buyer_name
    end
  end
end
