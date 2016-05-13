=begin
*****************************************************************
* File: app/controllers/documentation_controller.rb 
* Name: Class DocumentationController 
* 
*****************************************************************
=end

class DocumentationController < ApplicationController
  
  caches_page :api_v1
  
  def index
    redirect_to controller: :documentation, action: :api_v2
  end

# What is api_v1 and api_2 ?
  def api_v1
    @root = ENV['BASE_URL']
    render layout: 'documentation'
  end

  def api_v2
    if current_user.present?
      @applications = current_user.oauth_applications
    else
      cookies[:return_to] = api_v2_documentation_index_url
    end
    render layout: false
  end

  # Must discovery what's o2c 
  def o2c
    render layout: false
  end

  def authorize
    @accessCode = params[:code]
    @accessGrant = Doorkeeper::AccessGrant.where(resource_owner_id: current_user.id, token: @accessCode).last
    @application = @accessGrant.application if @accessGrant.present?
    render layout: 'content'
  end

end