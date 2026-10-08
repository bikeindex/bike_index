# frozen_string_literal: true

class BikebookController < ApplicationController
  def show
    model = params[:vehicle_models].to_s
    return render_vehicle(model) if model.match?(Integrations::BikeBook::Catalog::MODEL_ID)

    # comparisons and searches, whose models each have their own page
    response.headers["X-Robots-Tag"] = "noindex, follow" if request.query_parameters.present?
    render_page
  end

  # /bike_book/m/segway/2025/gt3_pro, or without its m/, picks that vehicle ahead of any already picked,
  # as /bike_book/evc/us/class_3 does that e-vehicle classification
  def vehicle
    path = params[:vehicle_model]
    id = path.start_with?("evc/") ? path : "m/#{path.delete_prefix("m/")}"
    picked = params[:vehicle_models].to_s.split(",")
    vehicle_models = [id, *picked].uniq
    query = request.query_parameters.merge("vehicle_models" => vehicle_models.join(","))
    # vehicle_sizes is in vehicle_models' order, so each size moves with its vehicle
    if params[:vehicle_sizes].present?
      sizes = picked.zip(params[:vehicle_sizes].split(",")).to_h
      query["vehicle_sizes"] = vehicle_models.map { sizes[it] }.join(",").sub(/,+\z/, "")
    end
    # unescaped, as the page writes its own URLs
    query = query.to_query.gsub("%2F", "/").gsub("%2C", ",")
    redirect_to "#{bike_book_path}?#{query}"
  end

  private

  # A model picked alone is its own page, canonically without the search's other params
  def render_vehicle(id)
    @page_url = "#{bike_book_url}?vehicle_models=#{id}"
    vehicle = Integrations::BikeBook::Catalog.vehicle(id) || fail(ActiveRecord::RecordNotFound)
    @page_description = vehicle[:description]
    @page_image = vehicle[:image_url]
    render_page(vehicle[:title])
  rescue Faraday::Error
    # the browser loads the catalog itself, and a crawler keeps the model's page and comes back
    render_page(status: :service_unavailable)
  end

  def render_page(title = "Bikebook", status: :ok)
    @page_title = title
    # the icon is taller than wide, which the large card crops to a banner
    @twitter_card = "summary" unless @page_image
    @page_image ||= helpers.image_url("logos/bikebook_icon.png")
    render Pages::Bikebook::Show::Component.new(manifest_url: Integrations::BikeBook::Catalog::MANIFEST_URL), status:
  end
end
