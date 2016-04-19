class InfoController < ApplicationController
  layout 'content'
  # caches_page :about, :where, :roadmap, :security, :serials, :stolen_bikes, :privacy, :terms, :vendor_terms, :downloads, :resources, :spokecard
  before_filter :set_active_section
  before_filter :set_revised_layout

  def about
  end
  
  def where
    @bike_shops = Organization.shop.shown_on_map.decorate
    @states = State.includes(:locations).all
    @countries = Country.where('iso != ?', 'US').includes(:locations)
  end

  def serials
  end

  def protect_your_bike
  end

  def privacy
    render layout: 'legal' unless revised_layout_enabled?
  end

  def terms
    render layout: 'legal' unless revised_layout_enabled?
  end

  def vendor_terms
    render layout: 'legal' unless revised_layout_enabled?
  end

  def resources
  end

  def image_resources
  end

  def support_the_index
    @page_title = 'Support the Bike Index'
    render layout: (revised_layout_enabled? ? 'application_revised' : 'application_updated')
  end

  def support_the_bike_index
    redirect_to support_the_index_url
  end

  def dev_and_design
  end

  def how_not_to_buy_stolen
    redirect_to 'https://files.bikeindex.org/stored/dont_buy_stolen.pdf'
  end

protected

  def set_active_section
    resources = %w(serials resources protect_your_bike image_resources)
    if resources.include? action_name
      @active_section = 'resources'
    else
      @active_section = 'about'
    end
  end


end