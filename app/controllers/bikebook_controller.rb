# frozen_string_literal: true

class BikebookController < ApplicationController
  # In development, a catalog `load:publish_catalog` wrote, served from here: its own app sends no CORS headers
  LOCAL_CATALOG_DIRECTORY = (ENV["BIKEBOOK_CATALOG_DIRECTORY"].presence if Rails.env.development?)
  LOCAL_CATALOG_PATH = "/bikebook_catalog"
  MANIFEST_URL = LOCAL_CATALOG_DIRECTORY ? "#{LOCAL_CATALOG_PATH}/manifest.json" : "https://bikebook-catalog.bikeindex.org/catalog/manifest.json"

  def show
    @page_title = "Bikebook"
    render Pages::Bikebook::Show::Component.new(manifest_url: MANIFEST_URL)
  end

  # /bikebook/m/segway/2025/gt3_pro, or without its m/, picks that vehicle ahead of any already picked,
  # as /bikebook/evc/us/class_3 does that e-vehicle classification
  def vehicle
    path = params[:vehicle_model]
    id = path.start_with?("evc/") ? path : "m/#{path.delete_prefix("m/")}"
    picked = params[:vehicle_models].to_s.split(",")
    vehicle_models = [id, *picked].uniq
    query = request.query_parameters.merge("vehicle_models" => vehicle_models.join(","))
    # vehicle_sizes is in vehicle_models' order, so each size moves with its vehicle
    sizes = params[:vehicle_sizes].to_s.split(",")
    if sizes.any?
      query["vehicle_sizes"] = vehicle_models.map { |each| sizes[picked.index(each) || sizes.length] }.join(",").sub(/,+\z/, "")
    end
    # unescaped, as the page writes its own URLs
    query = query.to_query.gsub("%2F", "/").gsub("%2C", ",")
    redirect_to "#{bikebook_path}?#{query}"
  end
end
