# frozen_string_literal: true

class StravaIntegrationsController < ApplicationController
  include Sessionable

  before_action :authenticate_user_for_strava
  before_action :find_strava_integration, only: %i[destroy sync_status]

  def new
    state = SecureRandom.hex(24)
    session[:strava_oauth_state] = state
    session[:strava_return_to] = params[:return_to] if params[:return_to]&.start_with?("/")
    # If scope is nil, it uses default scope
    scope = Integrations::StravaClient::STRAVA_SEARCH_SCOPE if params[:scope] == "strava_search"
    redirect_to Integrations::StravaClient.authorization_url(state:, scope:), allow_other_host: true
  end

  def callback
    if params[:error].present?
      flash[:error] = "Strava authorization was denied."
      redirect_to my_account_path
      return
    end

    unless params[:state].present? && session_state_matches?(session.delete(:strava_oauth_state))
      flash[:error] = "Invalid OAuth state. Please try again."
      redirect_to my_account_path
      return
    end

    token_data = Integrations::StravaClient.exchange_token(params[:code])
    if token_data.blank?
      flash[:error] = "Unable to connect to Strava. Please try again."
      redirect_to my_account_path
      return
    end

    strava_integration = find_or_create_strava_integration(token_data)

    if strava_integration.previously_new_record?
      StravaJobs::FetchAthleteAndStats.perform_async(strava_integration.id)
      flash[:success] = "Strava connected! Your activities are being synced."
    else
      flash[:success] = "Strava connection updated!"
    end
    return_to = session.delete(:strava_return_to)
    redirect_to return_to || (strava_integration.has_activity_write? ? strava_search_path : my_account_path)
  end

  def destroy
    @strava_integration.destroy
    flash[:success] = "Strava integration removed."
    redirect_to my_account_path
  end

  def sync_status
    render json: {
      status: @strava_integration.status,
      activities_downloaded_count: @strava_integration.activities_downloaded_count,
      athlete_activity_count: @strava_integration.athlete_activity_count,
      progress_percent: @strava_integration.sync_progress_percent
    }
  end

  private

  def authenticate_user_for_strava
    store_return_and_authenticate_user(translation_key: :create_account, flash_type: :info)
  end

  def find_strava_integration
    @strava_integration = current_user.strava_integration
    unless @strava_integration
      flash[:error] = "No Strava integration found."
      redirect_to my_account_path
    end
  end

  def token_attrs(token_data)
    {
      access_token: token_data["access_token"],
      refresh_token: token_data["refresh_token"],
      token_expires_at: Time.at(token_data["expires_at"]),
      athlete_id: token_data.dig("athlete", "id")&.to_s,
      strava_permissions: params[:scope]
    }
  end

  def find_or_create_strava_integration(token_data)
    attrs = token_attrs(token_data)
    existing_strava_integration = current_user.strava_integration
    if existing_strava_integration&.athlete_id == attrs[:athlete_id] && !existing_strava_integration.error?
      existing_strava_integration.update!(attrs)
      existing_strava_integration
    else
      existing_strava_integration&.destroy
      current_user.create_strava_integration!(attrs)
    end
  end

  def session_state_matches?(session_state)
    return true if ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, session_state.to_s)
    Rails.error.report(StandardError.new("Invalid Strava OAuth state"),
      context: {user_id: current_user.id, param_state: params[:state], session_state:})
    false
  end
end
