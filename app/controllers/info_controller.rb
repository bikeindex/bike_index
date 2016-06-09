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
  

  # Explication: set a variable 
  # Params: Organization.shown_on_map
  # Return: @organizations
  def where
    @organizations = Organization.shown_on_map
  end

  def serials
  end

  def protect_your_bike
  end

# Explication: render a layout with one condition
  def privacy
    render layout: 'legal' unless revised_layout_enabled?
  end

# Explication: render a layout with one condition
  def terms
    render layout: 'legal' unless revised_layout_enabled?
  end

# Explication: render a layout with one condition
  def vendor_terms
    render layout: 'legal' unless revised_layout_enabled?
  end

  def resources
  end

  def image_resources
  end

=begin
  Name: suport_the_index
  Explication: get a text and render in layout
  Params: text
  Return: render layout
=end 
  def support_the_index
    @pageTitle = 'Support the Bike Index'
    render layout: (revised_layout_enabled? ? 'application_revised' : 'application_updated')
  end

# Explication: reditect so support
  def support_the_bike_index
    redirect_to support_the_index_url
  end

  def dev_and_design
  end

# Explication: reditect so stolen bike page
  def how_not_to_buy_stolen
    redirect_to 'https://files.bikeindex.org/stored/dont_buy_stolen.pdf'
  end

protected

=begin
  Name: set_activeSection
  Explication: set active text with some condition
  Params: text
  Return: @activeSection
=end 
  def set_activeSection
    resources = %w(serials resources protect_your_bike image_resources)
    if resources.include? action_name
      @activeSection = 'resources'
    else
      @activeSection = 'about'
    end
  end


end