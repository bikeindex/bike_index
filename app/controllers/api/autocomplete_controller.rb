module API
  class AutocompleteController < ApplicationController
    respond_to :json
    before_action :cors_preflight_check
    after_action :cors_set_access_control_headers

    def index
      render json: {matches: Autocomplete::Matcher.search(permitted_params)}
    end

    protected

    def permitted_params
      params.permit(:page, :per_page, :categories, :q, :cache)
    end
  end
end
