class InfoController < ApplicationController
  layout 'content'
  # caches_page :about, :where, :roadmap, :security, :serials, :stolen_bikes, :privacy, :terms, :vendor_terms, :downloads, :resources, :spokecard
  def about
    @active_section = "about"
  end
  
  def where
    @active_section = "about"
    @shops = Organization.shown_on_map
    @locations = Location.by_state
    # @locations = Locations.shown_on_map.order("created_at asc")
  end

  def roadmap
    @active_section = "about"
  end

  def security
    @active_section = "about"
  end

  def serials
    @active_section = "resources"
  end

  def protect_your_bike
    @active_section = "about"
  end

  def stolen_bikes
    @active_section = "resources"
  end

  def privacy
    render layout: 'legal'
  end

  def terms
    render layout: 'legal'
  end

  def vendor_terms
    render layout: 'legal'
  end

  def resources
    @active_section = "resources"
  end

  def spokecard
    @active_section = "resources"
    if current_user.present?
      @bikes = Bike.find(current_user.bikes)
    end
  end
end