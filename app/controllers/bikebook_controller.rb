# frozen_string_literal: true

class BikebookController < ApplicationController
  # A model picked alone is its own page, which a shared link to it should be
  def show
    model = params[:vehicle_models].to_s
    return redirect_to_model(model, request.query_parameters.except("vehicle_models")) if model.match?(Integrations::BikebookCatalog::MODEL_ID)

    # comparisons and searches, whose models each have their own page
    response.headers["X-Robots-Tag"] = "noindex, follow" if request.query_parameters.present?
    render_page
  end

  # /bikebook/m/segway/2025/gt3_pro, or without its m/, is that model's page. With vehicles already picked,
  # it picks that vehicle ahead of them, as /bikebook/evc/us/class_3 does that e-vehicle classification
  def vehicle
    path = params[:vehicle_model]
    id = path.start_with?("evc/") ? path : "m/#{path.delete_prefix("m/")}"
    picked = params[:vehicle_models].to_s.split(",")
    return render_vehicle(id) if picked.none? && id.match?(Integrations::BikebookCatalog::MODEL_ID)

    vehicle_models = [id, *picked].uniq
    query = request.query_parameters.merge("vehicle_models" => vehicle_models.join(","))
    # vehicle_sizes is in vehicle_models' order, so each size moves with its vehicle
    if params[:vehicle_sizes].present?
      sizes = picked.zip(params[:vehicle_sizes].split(",")).to_h
      query["vehicle_sizes"] = vehicle_models.map { sizes[it] }.join(",").sub(/,+\z/, "")
    end
    redirect_to bikebook_url_with(bikebook_path, query)
  end

  private

  def render_vehicle(id)
    return redirect_to_model(id, request.query_parameters) if params[:vehicle_model] != id

    vehicle = Integrations::BikebookCatalog.vehicle(id) || fail(ActiveRecord::RecordNotFound)
    @page_description = vehicle.description
    @page_image = vehicle.image_url
    render_page(vehicle.title)
  rescue Faraday::Error
    render_page
  end

  def render_page(title = "Bikebook")
    @page_title = title
    render Pages::Bikebook::Show::Component.new(manifest_url: Integrations::BikebookCatalog::MANIFEST_URL)
  end

  def redirect_to_model(id, query)
    redirect_to bikebook_url_with("#{bikebook_path}/#{id}", query), status: :moved_permanently
  end

  # unescaped, as the page writes its own URLs
  def bikebook_url_with(path, query)
    [path, query.to_query.gsub("%2F", "/").gsub("%2C", ",").presence].compact.join("?")
  end
end
