class InfoController < ApplicationController
  def show
    @blog = Blog.friendly_find(params[:id])
    if @blog.blank?
      flash[:error] = "unable to find that page"
      redirect_to(news_path) && return
    elsif @blog.blog?
      redirect_to(news_path(@blog.to_param)) && return
    end
    @blogger = @blog.user
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

  def security_policy
  end

  def vendor_terms
  end

  def resources
  end

  def image_resources
  end

  def support_bike_index
    @page_title = "Support Bike Index"
    render layout: "payments_layout"
  end

  def support_the_index
    redirect_to support_bike_index_url
  end

  def support_the_bike_index
    redirect_to support_the_index_url
  end

  def dev_and_design
  end

  def how_not_to_buy_stolen
    redirect_to "https://files.bikeindex.org/stored/dont_buy_stolen.pdf"
  end
end
