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

    it "answers a Turbo submission redirected here as HTML" do
      get "/shop", headers: {"Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"}
      expect(response.media_type).to eq "text/html"
    end
  end

  describe "/store" do
    it "redirects to the shop, keeping the query" do
      expect(get("/store?utm_source=newsletter")).to redirect_to("/shop?utm_source=newsletter")
    end
  end

  describe "the store's info post" do
    let!(:blog) { FactoryBot.create(:blog, title: Blog.store_slug) }

    it "redirects to the shop" do
      get "/info/#{blog.title_slug}"
      expect(response).to redirect_to(shop_path)
    end
  end
end
