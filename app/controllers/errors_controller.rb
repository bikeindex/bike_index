=begin
*****************************************************************
* File: app/controllers/errors_controller.rb 
* Name: Class ErrorsController 
* Set some errors methods
*****************************************************************
=end

class ErrorsController < ApplicationController
  respond_to :html, :xml, :json
 
=begin    
  Name: bad_request
  Explication: just a rrender error page
=end
  def bad_request
    render status: 400
  end

=begin    
  Name: bad_request
  Explication: just a rrender error page
=end
  def not_found
    render status: 404
  end

=begin    
  Name: bad_request
  Explication: just a rrender error page
=end
  def unprocessable_entity
    render status: 422
  end

=begin    
  Name: bad_request
  Explication: just a rrender error page
=end
  def server_error
    render status: 500
  end

=begin    
  Name: bad_request
  Explication: just a rrender error page
=end
  def unauthorized
    render status: 401
  end

end