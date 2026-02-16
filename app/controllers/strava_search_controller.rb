# frozen_string_literal: true

class StravaSearchController < ApplicationController
  def index
    render file: Rails.root.join("public/strava_search/index.html"), layout: false
  end
end
