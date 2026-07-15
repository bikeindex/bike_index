# frozen_string_literal: true

module API
  # OAuth-authenticated JSON status endpoints for local agents/tooling.
  # Gated on a superuser ability for controller_name "admin_data".
  class AdminDataController < ApplicationController
    include API::TokenAuthenticatable

    ADMIN_DOORKEEPER_APP_ID = ENV.fetch("ADMIN_DOORKEEPER_APP_ID", 54).to_i

    respond_to :json
    before_action :require_admin_data_superuser!

    def sidekiq
      render json: AdminData::SidekiqStatus.call
    end

    def pghero
      render json: AdminData::PgheroStatus.call
    end

    private

    def authorized_app?(access_token)
      access_token.application_id == ADMIN_DOORKEEPER_APP_ID
    end

    def require_admin_data_superuser!
      auth = authorize_user(doorkeeper_token)
      return render(json: {error: auth[:error]}, status: auth[:status]) if auth[:error]
      return if auth[:user].superuser?(controller_name:, action_name:)

      render json: {error: "Not permitted"}, status: 403
    end
  end
end
