module API
  module V2
    module Defaults
      extend ActiveSupport::Concern
      included do 
        formatter :json, Grape::Formatter::ActiveModelSerializers
        
        before do
          header['Access-Control-Allow-Origin'] = '*'
          header['Access-Control-Request-Method'] = '*'
        end

        helpers do
          def current_token
            doorkeeper_access_token
          end
          
          def current_user
            resource_owner
          end

          def current_scopes
            current_token.scopes
          end
        end
      
      end
    end
  end
end