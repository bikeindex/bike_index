=begin
*****************************************************************
* File: app/controllers/info_controller.rb 
* Name: Class InfoController 
* Define some redirect to unable user
*****************************************************************
=end

class InfoController < ApplicationController
  
  layout 'content'

=begin
  caches_page :about, :where, :roadmap, :security, :serials, :stolen_bikes, :privacy, :terms, :vendor_terms, :downloads, :resources, :spoke_card
=end 
  
  before_filter :set_activeSection
  before_filter :set_revised_layout

  def about
  end
  
  def where
    @organizations = Organization.shown_on_map
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
    @pageTitle = 'Support the Bike Index'
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

  def set_activeSection
    resources = %w(serials resources protect_your_bike image_resources)
    if resources.include? action_name
      @activeSection = 'resources'
    else
      @activeSection = 'about'
    end
  end


end