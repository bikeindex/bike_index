=begin
*****************************************************************
* File: app/controllers/stolen_controller.rb 
* Name: Class StolenController 
* Set some methods to deal with stolen in bike
*****************************************************************
=end

class StolenController < ApplicationController
  before_filter :remove_subdomain
  layout 'application_updated'
  
  def index
    @feedback = Feedback.new
    assert_object_is_not_null(@feedback)
    assert_message(@feedback.kind_of?(Feedback))
    return @feedback
  end

  def current_tsv
    redirect_to 'https://files.bikeindex.org/uploads/tsvs/current_stolen_bikes.tsv'
  end

  def show
    redirect_to stolen_index_url
  end

  def multi_serial_search
    render layout: 'multi_serial'
  end

  private
  def remove_subdomain
    redirect_to stolen_index_url(subdomain: false) if request.subdomain.present?
  end

end