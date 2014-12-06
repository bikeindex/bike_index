class DocumentationController < ApplicationController
  layout 'documentation'
  caches_page :api_v1
  
  def index
    redirect_to controller: :documentation, action: :api_v1
  end

  def api_v1
    @root = ENV['BASE_URL']
  end

  def api_v2
    @applications = current_user.oauth_applications if current_user.present?
    render layout: false
  end

  def o2c
    render layout: false
  end

end