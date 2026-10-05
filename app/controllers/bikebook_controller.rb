# frozen_string_literal: true

class BikebookController < ApplicationController
  MANIFEST_URL = "https://bikebook-catalog.bikeindex.org/catalog/manifest.json"

  def show
    @page_title = "Bikebook"
    render Pages::Bikebook::Show::Component.new(manifest_url: MANIFEST_URL,
      standard_wheel_sizes: WheelSize.standard.pluck(:iso_bsd))
  end
end
