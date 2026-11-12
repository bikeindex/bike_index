# frozen_string_literal: true

class BikebookController < ApplicationController
  def show
    entries = Integrations::Bikebook::Catalog.vehicle_entries(params[:vehicle_models])
    model = Integrations::Bikebook::Catalog.vehicle_id(entries.first) if entries.one?
    return render_vehicle(model) if model&.match?(Integrations::Bikebook::Catalog::MODEL_ID)

    # comparisons and searches, whose models each have their own page
    response.headers["X-Robots-Tag"] = "noindex, follow" if request.query_parameters.present?
    render_page
  end

  def license
    @page_title = "Bike Book license and attribution | Bike Index"
    @page_description = "Bike Book data is open under CC BY-SA 4.0. Here's how to use it and how to credit Bike Index."
    @page_url = "https://bikeindex.org/bikebook/license"
  end

  def badge
    @page_title = "Powered by Bike Index badge | Bike Index"
    @page_description = "Download the Powered by Bike Index badge, for projects that use Bike Book data."
  end

  # /bikebook/m/segway/2025/gt3_pro, or without its m/, or its id alone, /m/segway/2025/gt3_pro, picks that vehicle ahead
  # of any already picked, with what's picked for it there
  def vehicle
    id = "m/#{params[:vehicle_model].delete_prefix("m/")}"
    picked, others = Integrations::Bikebook::Catalog.vehicle_entries(params[:vehicle_models])
      .partition { Integrations::Bikebook::Catalog.vehicle_id(it) == id }
    query = request.query_parameters.merge("vehicle_models" => [picked.first || id, *others].join(","))
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

  def render_page(title = "Bike Book", status: :ok)
    @page_title = title
    # the icon is taller than wide, which the large card crops to a banner
    @twitter_card = "summary" unless @page_image
    @page_image ||= helpers.image_url("logos/bikebook_icon.png")
    render Pages::Bikebook::Show::Component.new(manifest_url: Integrations::Bikebook::Catalog::MANIFEST_URL,
      market: request.env["HTTP_CF_IPCOUNTRY"], state: EbikeRuleServices::StateLaws.state_from_location(request_location_hash),
      query: request.query_parameters, paint_colors: Color.displays), status:
  end
end
