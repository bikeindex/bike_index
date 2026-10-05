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

  # /bikebook/m/segway/2025/gt3_pro, or without its m/, picks that vehicle ahead of any already picked
  def vehicle
    id = "m/#{params[:vehicle_model].delete_prefix("m/")}"
    vehicle_models = [id, *params[:vehicle_models].to_s.split(",")].uniq.join(",")
    # unescaped, as the page writes its own URLs
    query = request.query_parameters.merge("vehicle_models" => vehicle_models).to_query.gsub("%2F", "/").gsub("%2C", ",")
    redirect_to "#{bikebook_path}?#{query}"
  end
end
