# frozen_string_literal: true

module SearchResults::BikeBox
  class Component < ApplicationComponent
    include BikeHelper

    # NOTE: be cautious about passing in current_user and caching,
    # since current_user shows their hidden serials
    def initialize(bike:, current_user: nil, current_event_record: nil, skip_cache: false)
      @bike = bike
      return if @bike.blank?

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

    def render_for_sale_info?
      @bike.is_for_sale? && @current_event_record.is_a?(MarketplaceListing)
    end

    def occurred_at_with_fallback
      @bike.occurred_at || @current_event_record&.updated_at || @bike.updated_at
    end

    # copies from application_helper
    # TODO: replace with DefinitionList::Container::Component
    def attr_list_item(desc, title)
      return nil unless desc.present?
      content_tag(:li) do
        content_tag(:strong, "#{title}: ", class: "attr-title") +
          content_tag(:span, desc)
      end
    end
  end
end
