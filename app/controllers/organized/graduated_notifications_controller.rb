module Organized
  class GraduatedNotificationsController < Organized::BaseController
    include SortableTable
    before_action :ensure_access_to_graduated_notifications!
    before_action :set_period, only: [:index]
    before_action :find_graduated_notification, except: [:index]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)

      @graduated_notifications = available_graduated_notifications.reorder("graduated_notifications.#{sort_column} #{sort_direction}")
                          .page(@page).per(@per_page)
                          .includes(:user, :bike)
    end

    def show; end

    def email
      @organization = current_organization
      @email_preview = true
      @bike = @graduated_notification.bike
      @bikes = @graduated_notification.associated_bikes
      @retrieval_link_url = @graduated_notification.marked_remaining_link_token.present? ? "#" : nil
      render template: "/organized_mailer/graduated_notification", layout: "email"
    end

    private

    def graduated_notifications
      current_organization.graduated_notifications
    end

    def sortable_columns
      %w[created_at processed_at email marked_remaining_at]
    end

    def bike_search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? || params[:search_email].present?
    end

    def available_graduated_notifications
      return @available_graduated_notifications if defined?(@available_graduated_notifications)
      if params[:search_status] == "all"
        @search_status = "all"
        a_graduated_notifications = graduated_notifications
      else
        @search_status = GraduatedNotification.statuses.include?(params[:search_status]) ? params[:search_status] : "current"
        a_graduated_notifications = graduated_notifications.send(@search_status)
      end

      if bike_search_params_present?
        bikes = a_graduated_notifications.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:search_email]) if params[:search_email].present?
        a_graduated_notifications = a_graduated_notifications.where(bike_id: bikes.pluck(:id))
      end

      @available_graduated_notifications = a_graduated_notifications.where(created_at: @time_range)
    end

    def find_graduated_notification
      @graduated_notification = graduated_notifications.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @graduated_notification.present?
    end

    def ensure_access_to_graduated_notifications!
      return true if current_organization.deliver_graduated_notifications?
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to organization_bikes_path(organization_id: current_organization.to_param)
      return
    end
  end
end
