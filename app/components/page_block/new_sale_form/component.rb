# frozen_string_literal: true

module PageBlock::NewSaleForm
  class Component < ApplicationComponent
    def initialize(sale:, item:, marketplace_message: nil)
      @sale = sale
      @item = item
      @marketplace_message = marketplace_message
    end
  end
end
