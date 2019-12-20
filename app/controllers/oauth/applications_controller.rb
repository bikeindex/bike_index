module Oauth
  class ApplicationsController < Doorkeeper::ApplicationsController
    include ControllerHelpers
    before_action :authenticate_user
    before_action :ensure_app_owner!, except: [:index, :new, :create]

    def index
      @applications = current_user.oauth_applications.order(created_at: :desc)
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
          expires_in: nil, scopes: "write_bikes",
        )

        redirect_to oauth_application_url(@application)
      else
        render :new
      end
    end

    private

    def ensure_app_owner!
      return true if @current_user.superuser? || @current_user.id == @application.owner_id
      flash[:error] = translation(:not_your_application)
      redirect_to oauth_applications_url and return
    end
  end
end
