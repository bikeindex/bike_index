# frozen_string_literal: true

module PageBlock::NewSaleForm
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      render(PageBlock::NewSaleForm::Component.new(currency: Currency.default, sale:,
        marketplace_message:))
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
