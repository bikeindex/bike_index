class DocumentationController < ApplicationController
  caches_page :api_v1
  
  def index
    redirect_to controller: :documentation, action: :api_v1
  end

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

  def o2c
    render layout: false
  end

  def authorize
    @access_code = params[:code]
    @access_grant = Doorkeeper::AccessGrant.where(resource_owner_id: current_user.id, token: @access_code).last
    @application = @access_grant.application if @access_grant.present?
    render layout: 'content'
  end

end