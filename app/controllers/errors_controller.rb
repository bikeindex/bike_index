class ErrorsController < ApplicationController
  respond_to :html, :json
  before_filter :set_permitted_format
  layout 'application_revised'

  def bad_request
    render status: 400
  end

  def not_found
    render status: 404
  end

  def unprocessable_entity
    render status: 422
  end

  def server_error
    render status: 500
  end

  def unauthorized
    render status: 401
  end

  private

  def set_permitted_format
    request.format = 'html' unless request.format == 'json'
  end
end
