module Api
  module V1
    class DocumentationController < ApplicationController

      def index
        render action: 'index', layout: 'documentation', :formats=>[:html]
      end

    end
  end
end