module Organized
  class GraduatedNotificationsController < Organized::BaseController
    include SortableTable
    before_action :ensure_access_to_graduated_notifications!
    before_action :set_period, only: [:index]
    before_action :find_graduated_notification, except: [:index]

    def index
      @per_page = params[:per_page] || 25
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)

      @pagy, @graduated_notifications = pagy(available_graduated_notifications.reorder("graduated_notifications.#{sort_column} #{sort_direction}")
        .includes(:user, :bike, :secondary_notifications), limit: @per_page)
    end

    def show
    end

    helper_method :user_search_params_present?, :separate_secondary_notifications?

    private

    def graduated_notifications
      current_organization.graduated_notifications
    end

    def sortable_columns
      %w[created_at processed_at email marked_remaining_at]
    end

    def user_search_params_present?
      %i[search_email user_id].any? { |k| params[k].present? }
    end

    def separate_secondary_notifications?
      @separate_secondary_notifications ||= InputNormalizer.boolean(params[:search_secondary])
    end

    def search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? ||
        params[:search_bike_id].present?
    end

    def available_graduated_notifications
      return @available_graduated_notifications if defined?(@available_graduated_notifications)
      if params[:search_status] == "all"
        @search_status = "all"
        a_graduated_notifications = graduated_notifications
      else
        @search_status = GraduatedNotification.statuses.include?(params[:search_status]) ? params[:search_status] : "current"
        a_graduated_notifications = graduated_notifications.public_send(@search_status)
      end

      # Doesn't make sense to include unprocessed if sorting by processed_at
      if sort_column == "processed_at"
        a_graduated_notifications = a_graduated_notifications.where.not(processed_at: nil)
      end

      if search_params_present?
        bikes = a_graduated_notifications.bikes.search(@interpreted_params)
        bikes = Bike.where(id: params[:search_bike_id]) if params[:search_bike_id].present?
        a_graduated_notifications = a_graduated_notifications.where(bike_id: bikes.pluck(:id))
      end
      if params[:user_id].present?
        @user = User.find_by_id(params[:user_id])
        # Don't use @user to lookup, so even if user isn't found, we still search the id
        a_graduated_notifications = a_graduated_notifications.where(user_id: params[:user_id])
      elsif params[:search_email].present?
        email = EmailNormalizer.normalize(params[:search_email])
        a_graduated_notifications = a_graduated_notifications.where("email ILIKE ?", "%#{email}%")
      end

      a_graduated_notifications = a_graduated_notifications.primary_notification unless separate_secondary_notifications?

      @available_graduated_notifications = a_graduated_notifications.where(created_at: @time_range)
    end

    def find_graduated_notification
      @graduated_notification = graduated_notifications.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @graduated_notification.present?
    end

    def ensure_access_to_graduated_notifications!
      return true if current_organization.enabled?("graduated_notifications") || current_user.superuser?
      raise_do_not_have_access!
    end
  end
end
