# frozen_string_literal: true

class BikebookController < ApplicationController
  # A model picked alone is its own page, which a shared link to it should be
  def show
    vehicle_models = params[:vehicle_models].to_s.split(",")
    if vehicle_models.one? && vehicle_models.first.match?(Integrations::BikebookCatalog::MODEL_ID)
      return redirect_to bikebook_url_with("#{bikebook_path}/#{vehicle_models.first}", request.query_parameters.except("vehicle_models")),
        status: :moved_permanently
    end

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
    return render_vehicle(id) if picked.none? && id.start_with?("m/")

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
    vehicle = Integrations::BikebookCatalog.vehicle(id) || fail(ActiveRecord::RecordNotFound)
    if params[:vehicle_model] != id
      return redirect_to bikebook_url_with("#{bikebook_path}/#{id}", request.query_parameters), status: :moved_permanently
    end

    render_page(vehicle)
  rescue Faraday::Error
    render_page
  end

  def render_page(vehicle = nil)
    @page_obj = vehicle
    @page_title = "Bikebook" unless vehicle
    render Pages::Bikebook::Show::Component.new(manifest_url: Integrations::BikebookCatalog::MANIFEST_URL)
  end

  # unescaped, as the page writes its own URLs
  def bikebook_url_with(path, query)
    [path, query.to_query.gsub("%2F", "/").gsub("%2C", ",").presence].compact.join("?")
  end
end
