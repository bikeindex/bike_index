module API
  class AutocompleteController < ApplicationController
    respond_to :json

    def index
      render json: {matches: Autocomplete::Matcher.search(permitted_params)}
    end

    protected

    def permitted_params
      params.permit(:page, :per_page, :categories, :q, :cache)
    end
  end
end
