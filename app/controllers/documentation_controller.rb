class DocumentationController < ApplicationController
  before_action :render_swagger_for_page, only: [:api_v3, :api_v2]
  layout false

  def index
    redirect_to controller: :documentation, action: :api_v3
  end

  def api_v1
    redirect_to documentation_index_path
  end

  def api_v2
  end

  def api_v3
  end

  def o2c
  end

  def authorize
    @access_code = params[:code]
    @access_grant = Doorkeeper::AccessGrant.where(resource_owner_id: current_user_or_unconfirmed_user&.id, token: @access_code).last
    @application = @access_grant.application if @access_grant.present?
  end

  private

  def render_swagger_for_page
    if current_user.present?
      @applications = current_user.oauth_applications.reorder(created_at: :desc)
    else
      cookies[:return_to] = api_v3_documentation_index_url
    end
  end
end
