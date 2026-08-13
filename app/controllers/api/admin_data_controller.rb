# frozen_string_literal: true

module API
  # OAuth-authenticated JSON status endpoints for local agents/tooling.
  # Gated on a superuser ability for controller_name "admin_data".
  class AdminDataController < ApplicationController
    include API::TokenAuthenticatable

    respond_to :json
    before_action :require_token_superuser!

    def sidekiq
      render json: AdminData::SidekiqStatus.call
    end

    def pghero
      render json: AdminData::PgheroStatus.call
    end
  end
end
