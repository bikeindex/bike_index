# frozen_string_literal: true

class StravaIntegrationsController < ApplicationController
  include Sessionable

  before_action :authenticate_user_for_strava
  before_action :find_strava_integration, only: %i[destroy sync_status]

  def new
    state = SecureRandom.hex(24)
    session[:strava_oauth_state] = state
    if params[:return_to]&.start_with?("/")
      session[:strava_return_to] = params[:return_to]
    elsif params[:scope] == "strava_search"
      session[:strava_return_to] = strava_search_path
    end
    # If scope is nil, it uses default scope
    scope = Integrations::Strava::Client::STRAVA_SEARCH_SCOPE if params[:scope] == "strava_search"
    redirect_to Integrations::Strava::Client.authorization_url(state:, scope:), allow_other_host: true
  end

  def callback
    return_to = session.delete(:strava_return_to) || my_account_path

    if params[:error].present?
      flash[:error] = "Strava authorization was denied."
      redirect_to return_to
      return
    end

    unless session_state_matches?(params[:state], session.delete(:strava_oauth_state))
      flash[:error] = "Invalid OAuth state. Please try again."
      redirect_to return_to
      return
    end

    unless sufficient_strava_permissions?(params[:scope])
      flash[:error] = "Bike Index needs permission to read your activities and profile."
      redirect_to return_to
      return
    end

    token_data = Integrations::Strava::Client.exchange_token(params[:code])
    if token_data.blank?
      flash[:error] = "Unable to connect to Strava. Please try again."
      redirect_to return_to
      return
    end

    strava_integration = find_or_create_strava_integration(token_data)

    if strava_integration.previously_new_record?
      StravaJobs::FetchAthleteAndStats.perform_async(strava_integration.id)
      flash[:success] = "Strava connected! Your activities are being synced."
    else
      flash[:success] = "Strava connection updated!"
    end

    redirect_to return_to
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
      strava_id: token_data.dig("athlete", "id")&.to_s,
      strava_permissions: params[:scope]
    }
  end

  def find_or_create_strava_integration(token_data)
    attrs = token_attrs(token_data)
    existing_strava_integration = current_user.strava_integration
    if existing_strava_integration&.strava_id == attrs[:strava_id] && !existing_strava_integration.error?
      existing_strava_integration.update!(attrs)
      existing_strava_integration
    else
      existing_strava_integration&.destroy
      current_user.create_strava_integration!(attrs)
    end
  end

  def sufficient_strava_permissions?(scope)
    return false if scope.blank?

    granted = scope.split(",")
    Integrations::Strava::Client::DEFAULT_SCOPE.split(",").all? { |s| granted.include?(s) }
  end

  def session_state_matches?(params_state, session_state)
    ActiveSupport::SecurityUtils.secure_compare(params_state.to_s, session_state.to_s)
  end
end
