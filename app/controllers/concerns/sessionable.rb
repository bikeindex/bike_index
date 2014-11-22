module Sessionable
  extend ActiveSupport::Concern

  def sign_in_and_redirect
    session[:last_seen] = Time.now
    if params[:session].present? && params[:session][:remember_me].present? && params[:session][:remember_me].to_s == '1'
      cookies.signed[:auth] = {secure: true, httponly: true, value: [@user.id, @user.auth_token]}
    else
      cookies.signed[:auth] = {secure: true, httponly: true, value: [@user.id, @user.auth_token]}
    end

    if session[:return_to].present?
      target = session[:return_to]
      session[:return_to] = nil
      if target.match('password_reset')
        flash[:notice] = "You've been logged in. Please reset your password"
        render action: :update_password and return
      elsif target.match(/\A#{ENV['BASE_URL']}/i).present? || target.match(/\A\//).present?
        redirect_to target and return
      end
    end

    if @user.superuser
      redirect_to admin_root_url, notice: "Logged in!" and return
    else
      redirect_to user_home_url, notice: "Logged in!" and return
    end
  end

end