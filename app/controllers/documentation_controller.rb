class DocumentationController < ApplicationController
  before_filter :render_swagger_for_page, only: [:api_v3, :api_v2]
  def index
    redirect_to controller: :documentation, action: :api_v3
  end

  def api_v1
    unless current_user && current_user.developer
      flash[:notice] = 'API V1 is deprecated, please use our current API version'
      redirect_to documentation_index_path and return
    end
    @root = ENV['BASE_URL']
    render layout: 'documentation'
  end

  def api_v2
  end

  def api_v3
  end

  def o2c
    render layout: false
  end

  def authorize
    @access_code = params[:code]
    @access_grant = Doorkeeper::AccessGrant.where(resource_owner_id: current_user.id, token: @access_code).last
    @application = @access_grant.application if @access_grant.present?
    render layout: "application"
  end

  private

  def render_swagger_for_page
    if current_user.present?
      @applications = current_user.oauth_applications
    else
      cookies[:return_to] = api_v3_documentation_index_url
    end
    render layout: false
  end
end
