class NoAccessTokenError < StandardError
end
class UnauthorizedAccessTokenError < StandardError
end
module API
  module V2
    module Defaults
      extend ActiveSupport::Concern
      included do 
        version 'v2'
        format :json
        formatter :json, Grape::Formatter::ActiveModelSerializers

        helpers do
          def current_token
            env['api.token']
          end
          
          def current_user
            @current_user ||= User.find(current_token.resource_owner_id) if current_token
          end

          def current_scopes
            current_token.scopes
          end
        end

        before do
          header['Access-Control-Allow-Origin'] = '*'
          header['Access-Control-Request-Method'] = '*'
        end

        doorkeeper_for :all

        rescue_from ActiveRecord::RecordNotFound do |e|
          e.message ||= "Not found"
          Rack::Response.new({message: e.message}.to_json, 404).finish
        end

        rescue_from NoAccessTokenError do |e|
          Rack::Response.new({message: "Unauthorized: no authentication present. Go to /oauth/applications to create an application. Read the documentation at /documentation/api_v2"}.to_json, 401).finish
        end

        unless Rails.env.production?
          rescue_from :all do |e|
            Rack::Response.new({
              # error: "internal-server-error",
              message: "#{e.message}",
              trace: e.backtrace[0,10]
            }.to_json, 500).finish
          end
        end

      end
    end
  end
end