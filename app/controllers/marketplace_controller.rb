# frozen_string_literal: true

class MarketplaceController < ApplicationController
  def how_it_works
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::Marketplace::HowItWorks::Component.new)
  end
end
