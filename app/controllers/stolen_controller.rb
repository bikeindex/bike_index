=begin
*****************************************************************
* File: app/controllers/stolen_controller.rb 
* Name: Class StolenController 
* Set some methods to deal with stolen in bike
*****************************************************************
=end

class StolenController < ApplicationController

  # The passed filters will be appended to the filter_chain and will execute before the action on this controller is performed
  before_filter :remove_subdomain
  layout 'application_updated'

=begin
  Name: index
  Explication: method used to create a new instance about Feedback  
  Params: none
  Return: @feedback
=end  
  def index
    @feedback = Feedback.new
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@feedback)
    assert_message(@feedback.kind_of?(Feedback))
    return @feedback
  end

=begin
  Name: current_tsv
  Explication: method used to redirect to page which inform about current stolen bikes  
  Params: none
  Return: redirect to 'https://files.bikeindex.org/uploads/tsvs/current_stolen_bikes.tsv' 
=end
  def current_tsv
    redirect_to 'https://files.bikeindex.org/uploads/tsvs/current_stolen_bikes.tsv'
  end

=begin
  Name: show
  Explication: method used to redirect and to show page which inform bike's stolen   
  Params: none
  Return: redirect to stolen_index_url 
=end
  def show
    redirect_to stolen_index_url
  end

=begin
  Name: multi_serial_search
  Explication: method used to display multi serial page 
  Params: none
  Return: render layout: 'multi_serial'
=end
  def multi_serial_search
    render layout: 'multi_serial'
  end

  private

=begin
  Name: remove_subdomain
  Explication: method used to redirect to stolen page if request subdomain is present and after to can remove him  
  Params: subdomain which is a branch of the main branch
  Return: nothing or redirect to stolen page if request subdomain is present
=end  
  def remove_subdomain
    redirect_to stolen_index_url(subdomain: false) if request.subdomain.present?
  end

end