# frozen_string_literal: true

module PageBlock::NewSaleForm
  class Component < ApplicationComponent
    def initialize(sale:, item: nil, marketplace_message: nil)
      @sale = sale
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
