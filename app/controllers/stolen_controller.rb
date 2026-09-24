# frozen_string_literal: true

class StolenController < ApplicationController
  CURRENT_TSV_URL = "https://files.bikeindex.org/uploads/tsvs/current_stolen_bikes.tsv"

  before_action :set_permitted_format, only: [:index]

  def index
    @feedback = Feedback.new
  end

  def current_tsv
    redirect_to(CURRENT_TSV_URL, allow_other_host: true)
  end

  def current_tsv_rapid
    redirect_to(CURRENT_TSV_URL, allow_other_host: true)
  end

  def show
    redirect_to stolen_index_url
  end

  private

  def set_permitted_format
    request.format = "html"
  end
end
