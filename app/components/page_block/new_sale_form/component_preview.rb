# frozen_string_literal: true

module PageBlock::NewSaleForm
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(PageBlock::NewSaleForm::Component.new(sale:, marketplace_message:))
    end

    private

    def sale
      sale, _ = Sale.build_and_authorize(user: lookbook_user, marketplace_message:)
      sale
    end

    def marketplace_message
      MarketplaceMessage.find(2)
    end
  end
end
