module Api
  module V1
    class DocumentationController < ApplicationController
      require 'httparty'
      caches_page :index
      
      def index
        render action: 'index', layout: 'documentation', :formats=>[:html]
      end

    end
  end
end