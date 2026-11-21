# frozen_string_literal: true

class ShopController < ApplicationController
  before_action :force_html_response

  def index
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::Shop::Index::Component.new)
  end
end
