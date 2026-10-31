# frozen_string_literal: true

class BikebookController < ApplicationController
  def show
    model = params[:vehicle_models].to_s
    return render_vehicle(model) if model.match?(Integrations::Bikebook::Catalog::MODEL_ID)

    # comparisons and searches, whose models each have their own page
    response.headers["X-Robots-Tag"] = "noindex, follow" if request.query_parameters.present?
    render_page
  end

  # /bikebook/m/segway/2025/gt3_pro, or without its m/, or its id alone, /m/segway/2025/gt3_pro, picks that vehicle ahead
  # of any already picked
  def vehicle
    path = params[:vehicle_model]
    id = "m/#{path.delete_prefix("m/")}"
    picked = params[:vehicle_models].to_s.split(",")
    vehicle_models = [id, *picked].uniq
    query = request.query_parameters.merge("vehicle_models" => vehicle_models.join(","))
    # vehicle_sizes and vehicle_colorways are in vehicle_models' order, so each pick moves with its vehicle
    %w[vehicle_sizes vehicle_colorways].each do |param|
      next if params[param].blank?
      picks = picked.zip(params[param].split(",")).to_h
      query[param] = vehicle_models.map { picks[it] }.join(",").sub(/,+\z/, "")
    end
    redirect_to ReadableQuery.path(bikebook_path, query)
  end

  private

  # A model picked alone is its own page, canonically without the search's other params
  def render_vehicle(id)
    @page_url = "#{bikebook_url}?vehicle_models=#{id}"
    vehicle = Integrations::Bikebook::Catalog.vehicle(id) || fail(ActiveRecord::RecordNotFound)
    @page_description = vehicle[:description]
    @page_image = vehicle[:image_url]
    render_page(vehicle[:title])
  rescue Integrations::Bikebook::Catalog::Unreachable
    # the browser loads the catalog itself, and a crawler keeps the model's page and comes back
    render_page(status: :service_unavailable)
  end

  def render_page(title = "BikeBook", status: :ok)
    @page_title = title
    # the icon is taller than wide, which the large card crops to a banner
    @twitter_card = "summary" unless @page_image
    @page_image ||= helpers.image_url("logos/bikebook_icon.png")
    render Pages::Bikebook::Show::Component.new(manifest_url: Integrations::Bikebook::Catalog::MANIFEST_URL,
      market: request.env["HTTP_CF_IPCOUNTRY"], state: EbikeRuleServices::StateLaws.state_from_location(request_location_hash),
      query: request.query_parameters, paint_colors: Color.pluck(:name, :display).to_h), status:
  end
end
