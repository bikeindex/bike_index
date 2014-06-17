class ErrorsController < ApplicationController
 
  def bad_request
    render status: 400, formats: [:html]
  end

  def not_found
    render status: 404, formats: [:html]
  end

  def unprocessable_entity
    render status: 422, formats: [:html]
  end

  def server_error
    render status: 500, formats: [:html]
  end

end