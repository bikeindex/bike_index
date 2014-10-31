class ErrorsController < ApplicationController
  respond_to :html, :xml, :json
 
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

end