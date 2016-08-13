module AuthenticationHelper
  extend ActiveSupport::Concern

  def authenticate_user(msg = 'Sorry, you have to log in', flash_type: :error)
    if current_user.present?
      unless current_user.terms_of_service
        redirect_to accept_terms_url(subdomain: false) and return
      end
    else
      flash[flash_type] = msg
      if msg.match(/create an account/i).present?
        redirect_to new_user_url(subdomain: false) and return
      else
        redirect_to new_session_url(subdomain: false) and return
      end
    end
  end

  def user_root_url
    return root_url unless current_user.present?
    if current_user.superuser
      admin_root_url
    elsif current_user.is_content_admin
      admin_news_index_url
    else
      user_home_url(subdomain: false)
    end
  end

  def revised_layout_enabled?
    (current_user && $rollout.active?(:revised_view, current_user)) || (params && params[:revised_layout])
  end

  protected

  def remove_session
    cookies.delete(:auth)

  end

  def current_user
    @current_user ||= User.from_auth(cookies.signed[:auth])
  end

  # def permitted_params
  #   @permitted_params ||= PermittedParams.new(params, current_user)
  # end

  def require_member!
    return true if current_user.is_member_of?(current_organization)
    flash[:error] = "You're not a member of that organization!"
    redirect_to user_home_url(subdomain: false) and return
  end

  def require_admin!
    unless current_user.is_admin_of?(current_organization)
      flash[:error] = 'You have to be an organization administrator to do that!'
      redirect_to user_home_url and return
    end
  end

  def require_index_admin!
    type = 'full'
    content_accessible = ['news']
    type = 'content' if content_accessible.include?(controller_name)
    unless current_user.present? && current_user.admin_authorized(type)
      flash[:error] = "You don't have permission to do that!"
      redirect_to user_root_url
    end
  end
end
