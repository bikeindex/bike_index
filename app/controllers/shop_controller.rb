# frozen_string_literal: true

class ShopController < ApplicationController
  def index
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::Shop::Index::Component.new)
  end
end
