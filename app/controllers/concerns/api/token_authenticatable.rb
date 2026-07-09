# frozen_string_literal: true

module API
  # OAuth bearer-token lookup for plain Rails controllers under the API namespace.
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    private

    def doorkeeper_token
      @doorkeeper_token ||= Doorkeeper::OAuth::Token.authenticate(
        request, *Doorkeeper.configuration.access_token_methods
      )
    end
  end
end
