# frozen_string_literal: true

module PageBlock::NewSaleForm
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(PageBlock::NewSaleForm::Component.new(sale:, item:, marketplace_message:))
    end
  end
end
