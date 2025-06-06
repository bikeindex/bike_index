# frozen_string_literal: true

module Search::BikeBox
  class Component < ApplicationComponent
    include BikeHelper

    # NOTE: be cautious about passing in current_user and caching,
    # since current_user shows their hidden serials
    def initialize(bike:, current_user: nil, current_event_record: nil, skip_cache: false)
      @bike = bike
      @current_event_record = @bike.current_event_record

      # If this is cached (assume it is by default), don't show the serial for the user
      @is_cached = !skip_cache
      @current_user = current_user unless @is_cached
    end

    def render?
      @bike.present?
    end

    private

    def render_second_column?
      @current_event_record.present?
    end

    # copied from application_helper
    def attr_list_item(desc, title)
      return nil unless desc.present?
      content_tag(:li) do
        content_tag(:strong, "#{title}: ", class: "attr-title") +
          content_tag(:span, desc)
      end
    end
  end
end
