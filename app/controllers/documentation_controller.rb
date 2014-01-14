class DocumentationController < ApplicationController
  layout 'documentation'
  caches_page :api_v1
  
  def index
    redirect_to controller: :documentation, action: :api_v1
  end

  def api_v1
    
  end

end