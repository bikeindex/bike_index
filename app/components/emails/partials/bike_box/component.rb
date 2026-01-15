# frozen_string_literal: true

module Emails::Partials::BikeBox
  class Component < ApplicationComponent
    def initialize(bike:, ownership:, bike_url_path:)
      @bike = bike
      @ownership = ownership
      @bike_url_path = bike_url_path
    end

    private

    def skip_link_tracking?
      @bike_url_path.match?(/\?/)
    end

    def thumb_url
      @bike.thumb_path || @bike.stock_photo_url || "https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"
    end

    def placeholder?
      @bike.thumb_path.blank? && @bike.stock_photo_url.blank?
    end

    def color_label
      translation("color").pluralize(@bike.frame_colors.count)
    end

    def show_paint_description?
      BikeServices::Displayer.paint_description?(@bike)
    end

    def stolen_record
      @bike.current_stolen_record
    end

    def show_color_warning?
      @ownership&.new_registration? && @bike.pos?
    end
  end
end
