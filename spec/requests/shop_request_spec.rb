# frozen_string_literal: true

require "rails_helper"

RSpec.describe ShopController, type: :request do
  describe "/shop" do
    it "renders the shop" do
      get "/shop"
      expect(response).to be_ok
      expect(response.body).to include("Gear that helps get bikes home.")
      expect(Capybara.string(response.body)).to have_title("Shop - Bike Index")
        .and have_css("meta[name='description'][content^='Bike Index caps and registration stickers']", visible: :all)
    end
  end

  describe "/store" do
    it "redirects to the shop" do
      expect(get("/store")).to redirect_to(shop_path)
    end
  end
end
