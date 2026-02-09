class StravaIntegrationsController < ApplicationController
  include Sessionable

  before_action :authenticate_user_for_strava
  before_action :find_strava_integration, only: %i[destroy sync_status]

  def new
    redirect_to Integrations::Strava.authorization_url, allow_other_host: true
  end

  def callback
    if params[:error].present?
      flash[:error] = "Strava authorization was denied."
      redirect_to my_account_path
      return
    end

    token_data = Integrations::Strava.exchange_token(params[:code])
    if token_data.blank?
      flash[:error] = "Unable to connect to Strava. Please try again."
      redirect_to my_account_path
      return
    end

    strava_integration = current_user.strava_integration || current_user.build_strava_integration
    strava_integration.update!(
      access_token: token_data["access_token"],
      refresh_token: token_data["refresh_token"],
      token_expires_at: Time.at(token_data["expires_at"]),
      athlete_id: token_data.dig("athlete", "id")&.to_s,
      status: :pending
    )

    StravaJobs::InitialSync.perform_async(strava_integration.id)

    flash[:success] = "Strava connected! Your activities are being synced."
    redirect_to my_account_path
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
end
