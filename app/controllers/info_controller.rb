# frozen_string_literal: true

class InfoController < ApplicationController
  DONT_BUY_STOLEN_URL = "https://files.bikeindex.org/stored/dont_buy_stolen.pdf"

  def show
    @blog = Blog.friendly_find(params[:id])
    if @blog.blank?
      flash[:error] = "unable to find that page"
      redirect_to(news_path) && return
    elsif @blog.title_slug == Blog.membership_slug
      redirect_to("/membership") && return
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

  def dev_and_design
    @bike_tile_images = (0..16).map { |i|
      helpers.image_url("kelsey/bike_tiles/bike-entry_00#{i.to_s.rjust(2, "0")}.png")
    }
    @design_resources = [
      {thumbnail: "kelsey/resources/logos.png", title: "Downloadable Logos", description: "All versions of the Bike Index shield logo as SVG and PNG files.", button_text: "Download Logo Pack", file: "/resources/bike-index-logo-pack.zip"},
      {thumbnail: "kelsey/resources/flyer.png", title: "Bulletin Board Flyer", description: "A printable 8.5x11\" flyer for your bulletin board! Has space to customize with your city, university, or community group.", button_text: "Download Flyer", file: "/resources/printable-flyer.jpg"},
      {thumbnail: "kelsey/resources/brochure.png", title: "Trifold Brochure", description: "A printable 8.5x11\" sheet you can fold into 3 panels. Print in full color and double-sided.", button_text: "Download Brochure", file: "/resources/bike-index-trifold.pdf"},
      {thumbnail: "kelsey/resources/shop-card.png", title: "Bike Shop Card", description: "Design is for notecard size (5.5\" x 4.25\").", button_text: "Download Shop Card", file: "/resources/bike-index-shop-card.pdf"},
      {thumbnail: "kelsey/resources/cool-bike-check.png", title: "Cool Bike Check", description: "Printable sheet with 4 Cool Bike Check tags.", button_text: "Download Tags", file: "/resources/cool-bike-check.pdf"},
      {thumbnail: "kelsey/resources/graphics-pack.png", title: "Graphics Pack", description: "Complete collection of illustrated graphics and visual assets for your projects and presentations.", button_text: "Download Graphics Pack", file: "/resources/graphics-pack.zip"}
    ]
    @dev_resources = [
      {title: "Bike Index on GitHub", description: "Bike Index itself is open source — check it out on GitHub.", link_text: "View on GitHub", url: "https://github.com/bikeindex/bike_index"},
      {title: "API Documentation", description: "Complete documentation for the Bike Index API.", link_text: "View API Docs", url: documentation_index_url},
      {title: "Nearby Stolen Widget", description: "Display nearby stolen bikes on your website.", link_text: "View Widget on GitHub", url: "https://github.com/bikeindex/stolen_bike_widget"},
      {title: "Personal Bike Display Widget", description: "Show your registered bikes on your personal website (requires login).", link_text: "Get Widget Code", url: "https://bikeindex.org/user_embeds"},
      {title: "OAuth Applications You've Made", description: "Manage OAuth applications you've created (requires login).", link_text: "Manage Applications", url: "https://bikeindex.org/oauth/applications"},
      {title: "OAuth Applications You've Authorized", description: "View and manage OAuth applications you've authorized (requires login).", link_text: "View Authorized Apps", url: "https://bikeindex.org/oauth/authorized_applications"}
    ]
  end

  def membership
    @blog = Blog.friendly_find(Blog.membership_slug)
    @page_id = "news_show" # Override to make styles same as news
    render "show"
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

  def how_not_to_buy_stolen
    redirect_to(DONT_BUY_STOLEN_URL, allow_other_host: true)
  end

  def primary_activities
    respond_to do |format|
      format.csv { render plain: Spreadsheets::PrimaryActivities.to_csv }
    end
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
