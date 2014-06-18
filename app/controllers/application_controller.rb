class ApplicationController < ActionController::Base
  include UrlHelper
  protect_from_forgery

protected
  def current_user
    begin
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    rescue ActiveRecord::RecordNotFound
      return nil
    end
    if @current_user.present?
      return @current_user
    else
      return nil
    end
  end
  helper_method :current_user

  # def permitted_params
  #   @permitted_params ||= PermittedParams.new(params, current_user)
  # end

  def organization_list
    @organization_list = Organization.all
  end
  helper_method :organization_list

  def authenticate_user!
    if current_user.present?
      unless current_user.terms_of_service
        redirect_to accept_terms_url(subdomain: false) and return
      end
    else
      flash[:error] = "You gotta log in!"
      redirect_to new_session_url(subdomain: false) and return
    end
  end

  def require_member!
    if current_user.is_member_of?(current_organization)
      return true
      # unless current_user.vendor_terms_of_service
      #   redirect_to accept_vendor_terms_url(subdomain: false) and return
      # end
    else
      flash[:error] = "You're not a member of that organization!"
      redirect_to user_home_url(subdomain: false) and return
    end
  end

  def require_admin!
    unless current_user.is_admin_of?(current_organization)
      flash[:error] = "You gotta be an organization administrator to do that!"
      redirect_to user_home_url and return
    end
  end

  def require_superuser!
    unless current_user.present? and current_user.superuser?
      flash[:error] = "Gotta be an admin. Srys"
      redirect_to user_home_url(subdomain: false) and return
    end
  end

  def current_organization
    @organization ||= Organization.find_by_slug(request.subdomain)
  end
  helper_method :current_organization

  def bust_cache!
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "#{1.year.ago}"
  end

  def set_current_organization
    if Subdomain.matches?(request)
      @organzation = Organization.find_by_slug(request.subdomain)
    end
  end

end
