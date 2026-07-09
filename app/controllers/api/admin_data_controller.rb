# frozen_string_literal: true

module API
  # OAuth-authenticated JSON status endpoints for local agents/tooling.
  # Gated on a superuser ability for controller_name "admin_data".
  class AdminDataController < ApplicationController
    respond_to :json
    before_action :require_admin_data_superuser!

    def sidekiq
      render json: AdminData::SidekiqStatus.call
    end

    def pghero
      render json: AdminData::PgheroStatus.call
    end

    private

    def require_admin_data_superuser!
      return true if oauth_user&.superuser?(controller_name:, action_name:)

      if oauth_user
        render json: {error: "Not permitted"}, status: 403
      else
        render json: {error: "OAuth token required"}, status: 401
      end
    end

    def oauth_user
      return @oauth_user if defined?(@oauth_user)

      token = doorkeeper_token
      @oauth_user = token&.accessible? ? User.confirmed.find_by(id: token.resource_owner_id) : nil
    end

    def doorkeeper_token
      @doorkeeper_token ||= Doorkeeper::OAuth::Token.authenticate(
        request, *Doorkeeper.configuration.access_token_methods
      )
    end
  end
end
