# frozen_string_literal: true

class BikebookController < ApplicationController
  # A catalog published locally (`bin/rails load:publish_catalog` writes it to the app's public/catalog),
  # served from here in development: the app serving it sends no CORS headers
  LOCAL_CATALOG_DIRECTORY = (ENV["BIKEBOOK_CATALOG_DIRECTORY"].presence if Rails.env.development?)
  LOCAL_CATALOG_PATH = "/bikebook_catalog"
  MANIFEST_URL = LOCAL_CATALOG_DIRECTORY ? "#{LOCAL_CATALOG_PATH}/manifest.json" : "https://bikebook-catalog.bikeindex.org/catalog/manifest.json"

  def show
    @page_title = "Bikebook"
    render Pages::Bikebook::Show::Component.new(manifest_url: MANIFEST_URL)
  end
end
