class StolenController < ApplicationController
  caches_page :index
  
  def index
    render action: 'index', layout: 'sbr'
  end

  def tsv_download
    tsv = "Make\tModel\tSerial\tDescription\tArticleOrGun\tDateOfTheft\tCaseNumber\tLEName\tLEContact\tComments\n"
    StolenRecord.where(current: true).where(approved: true).each { |r| tsv << r.tsv_row }
    send_data tsv, filename: 'stolen_bikes.tsv'
  end

end