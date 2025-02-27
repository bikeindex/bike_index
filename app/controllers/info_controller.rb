# frozen_string_literal: true

class InfoController < ApplicationController
  DONT_BUY_STOLEN_URL = "https://files.bikeindex.org/stored/dont_buy_stolen.pdf"

  def show
    @blog = Blog.friendly_find(params[:id])
    if @blog.blank?
      flash[:error] = "unable to find that page"
      redirect_to(news_path) && return
    elsif @blog.id == Blog.theft_rings_id
      redirect_to("/theft-rings") && return
    elsif @blog.blog?
      redirect_to(news_path(@blog.to_param)) && return
    end
    @page_id = "news_show" # Override to make styles same as news
  end

  def about
  end

  def where
    @organizations = Organization.show_on_map.includes(:locations)
  end

  def serials
  end

  def protect_your_bike
  end

  def lightspeed
    session[:return_to] = lightspeed_url unless current_user.present?
    @organization = Organization.new
  end

  def privacy
  end

  def terms
  end

  def security
  end

  def vendor_terms
  end

  def resources
  end

  def image_resources
  end

  def why_donate
    @blog = Blog.friendly_find(Blog.why_donate_slug)
    render "/news/show"
  end

  def donate
    @page_title = "Support Bike Index"
    render layout: "payments_layout"
  end

  def support_bike_index
    redirect_to_donation_or_payment
  end

  def support_the_index
    redirect_to_donation_or_payment
  end

  def support_the_bike_index
    redirect_to_donation_or_payment
  end

  def dev_and_design
  end

  def how_not_to_buy_stolen
    redirect_to(DONT_BUY_STOLEN_URL, allow_other_host: true)
  end

  private

  def redirect_to_donation_or_payment
    if params[:amount].present?
      redirect_to new_payment_path(amount: params[:amount])
    else
      redirect_to donate_url
    end
  end
end
