# frozen_string_literal: true

class MarketplaceController < ApplicationController
  def how_it_works
    render Pages::Marketplace::HowItWorks::Component.new
  end
end
