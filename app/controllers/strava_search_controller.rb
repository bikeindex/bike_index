# frozen_string_literal: true

class StravaSearchController < ApplicationController
  layout false

  def index
    render file: Rails.root.join("public/strava_search/index.html")
  end
end
