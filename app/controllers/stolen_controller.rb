class StolenController < ApplicationController
  before_filter :remove_subdomain
  layout 'application_updated'
  
  def index
    @feedback = Feedback.new
  end

  def current_tsv
    redirect_to 'https://s3.amazonaws.com/bikeindex/uploads/current_stolen_bikes.tsv'
  end

  def links
  end

  def about
  end

  def tech
  end

  def rfid_tags_for_the_win
  end

  def howworks
  end

  def merging
    @title = ' - stolen bike registration that works'
    stolen_bikes = StolenRecord.where(approved: true).order('date_stolen DESC').limit(6).pluck(:bike_id)
    @stolen_bikes = Bike.where('id in (?)', stolen_bikes).includes(:stolen_records).decorate
    @feedback = Feedback.new
    render action: 'index'
  end

  def multi_serial_search
    render layout: 'multi_serial'
  end

  private
  def remove_subdomain
    redirect_to stolen_index_url(subdomain: false) if request.subdomain.present?
  end

end