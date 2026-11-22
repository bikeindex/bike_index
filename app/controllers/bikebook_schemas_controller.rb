# frozen_string_literal: true

class BikebookSchemasController < ApplicationController
  def show
    json = Integrations::Bikebook::RepositoryRecord.json(params[:id])
    json ? render(json:) : render(json: {error: "Not found"}, status: :not_found)
  rescue Faraday::Error
    render json: {error: "The Bike Book repository isn't answering"}, status: :service_unavailable
  end
end
