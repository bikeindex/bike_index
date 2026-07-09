# frozen_string_literal: true

module API
  # OAuth-authenticated JSON status endpoints for local agents/tooling.
  # Gated on a superuser ability for controller_name "admin_data".
  class AdminDataController < ApplicationController
    include API::TokenAuthenticatable

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
      return if oauth_user&.superuser?(controller_name:, action_name:)

      error, status = oauth_user ? ["Not permitted", 403] : ["OAuth token required", 401]
      render json: {error:}, status:
    end

    def oauth_user
      return @oauth_user if defined?(@oauth_user)

      token = doorkeeper_token
      @oauth_user = token&.accessible? ? User.confirmed.find_by(id: token.resource_owner_id) : nil
    end
  end
end
