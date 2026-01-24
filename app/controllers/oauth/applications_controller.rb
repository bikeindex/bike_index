module Oauth
  class ApplicationsController < Doorkeeper::ApplicationsController
    include ControllerHelpers
    include SetPeriod
    include SortableTable
    include Pagy::Method

    before_action :store_return_and_authenticate_user
    before_action :ensure_app_owner!, except: %i[index new create]
    before_action :set_period, only: %i[index]

    def index
      if Binxtils::InputNormalizer.boolean(params[:search_all]) && current_user.superuser?
        @max_per_page = 500
        @per_page = permitted_per_page(default: 50, max: @max_per_page)

        @pagy, @collection = pagy(ordered_applications, limit: @per_page)
        @matching_applications = admin_oauth_applications

        render "admin_index", layout: "admin"
      else
        @applications = current_user.oauth_applications.order(id: :desc)
      end
    end

    # only needed if each application must have some owner
    def create
      @application = Doorkeeper::Application.new(application_params)
      @application.owner = current_user
      if @application.save
        flash[:notice] = translation(:notice, scope: %i[doorkeeper flash applications create])
        Doorkeeper::AccessToken.create!(
          application_id: @application.id,
          resource_owner_id: ENV["V2_ACCESSOR_ID"],
          expires_in: nil, scopes: "write_bikes"
        )

        redirect_to oauth_application_url(@application)
      else
        render :new
      end
    end

    private

    def sortable_columns
      %w[created_at name owner_id ownerships_count updated_at tokens_count]
    end

    def earliest_period_date
      Time.at(1415660930) # First Application created
    end

    def ordered_applications
      if params[:sort] == "tokens_count"
        admin_oauth_applications.left_joins(:access_tokens).group(:id)
          .order("count(oauth_applications.id) #{sort_direction}")
      else
        admin_oauth_applications.reorder("#{sort_column} #{sort_direction}")
      end
    end

    def admin_oauth_applications
      doorkeeper_apps = Doorkeeper::Application

      if params[:user_id].present?
        doorkeeper_apps = doorkeeper_apps.where(owner_id: user_subject&.id || params[:user_id])
      end

      @time_range_column = sort_column if %w[updated_at].include?(sort_column)
      @time_range_column ||= "created_at"
      doorkeeper_apps.where(@time_range_column => @time_range)
    end

    def ensure_app_owner!
      return true if @current_user&.superuser? || @current_user&.id == @application&.owner_id

      flash[:error] = translation(:not_your_application)
      redirect_to(oauth_applications_url) && return
    end
  end
end
