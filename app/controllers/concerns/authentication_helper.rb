# This isn't a concern so it can be included in the controller_helpers concern
module AuthenticationHelper
  def authenticate_user(msg = "Sorry, you have to log in", flash_type: :error)
    if current_user.present?
      return true if current_user.terms_of_service
      redirect_to accept_terms_url(subdomain: false) and return
    elsif unconfirmed_current_user.present?
      redirect_to please_confirm_email_users_path and return
    else
      flash[flash_type] = msg
      if msg.match(/create an account/i).present?
        redirect_to new_user_url(subdomain: false, partner: params[:partner]) and return
      else
        redirect_to new_session_url(subdomain: false, partner: params[:partner]) and return
      end
    end
  end

  def render_partner_or_default_signin_layout(render_action: nil, redirect_path: nil)
    # We set partner in session because of AuthorizationsController - but we don't want the session to stick around
    # so people can navigate around the site and return to the sign in without unexpected results
    partner = params[:partner] || session.delete(:partner)
    @partner = partner&.downcase == "bikehub" ? "bikehub" : nil # For now, only permit bikehub partner
    layout = @partner == "bikehub" ? "application_revised_bikehub" : "application_revised"
    if redirect_path
      redirect_to redirect_path, layout: layout
    elsif render_action
      render action: render_action, layout: layout
    else
      render layout: layout
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

  def ensure_preview_enabled!
    return true if preview_enabled?
    flash[:notice] = "Sorry, you don't have permission to view that page"
    redirect_to user_root_url and return
  end

  protected

  def remove_session
    cookies.delete(:auth)
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user ||= User.confirmed.from_auth(cookies.signed[:auth])
  end

  def unconfirmed_current_user
    return @unconfirmed_current_user if defined?(@unconfirmed_current_user)
    @unconfirmed_current_user ||= User.unconfirmed.from_auth(cookies.signed[:auth])
  end

  def preview_enabled?
    (current_user && $rollout.active?(:preview, current_user)) || (params && params[:preview])
  end

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
