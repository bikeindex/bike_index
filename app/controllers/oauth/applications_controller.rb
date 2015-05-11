# app/controllers/oauth/applications_controller.rb
class Oauth::ApplicationsController < Doorkeeper::ApplicationsController
  include AuthenticationHelper
  helper_method :current_user, :current_organization, :user_root_url
  before_filter :authenticate_user
  before_filter :set_current_user_instance
  before_filter :ensure_app_owner!, except: [:index, :new, :create]

  def index
    @applications = current_user.oauth_applications
  end

  # only needed if each application must have some owner
  def create
    @application = Doorkeeper::Application.new(application_params)
    @application.owner = current_user
    if @application.save
      flash[:notice] = I18n.t(:notice, :scope => [:doorkeeper, :flash, :applications, :create])
       # respond_with( :oauth, @application, location: oauth_application_url(@application) )
       Doorkeeper::AccessToken.create!(application_id: @application.id, resource_owner_id: ENV['V2_ACCESSOR_ID'], expires_in: nil, scopes: 'write_bikes')
       redirect_to oauth_application_url(@application)
    else
      render :new
    end
  end

  private
  def set_current_user_instance
    @current_user = current_user
  end

  def ensure_app_owner!
    return true if @current_user.superuser? || @current_user.id == @application.owner_id
    flash[:notice] = "That isn't your application"
    redirect_to oauth_applications_url and return
  end


end