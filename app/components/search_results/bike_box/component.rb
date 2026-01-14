# frozen_string_literal: true

module SearchResults::BikeBox
  class Component < ApplicationComponent
    include BikeHelper

    # NOTE: be cautious about passing in current_user and caching,
    # since current_user shows their hidden serials
    def initialize(bike:, current_user: nil, event_record: nil, search_kind: nil, skip_cache: false, render_removed: false)
      @render_removed = render_removed
      return if bike.blank? || !@render_removed && bike.deleted?

      @bike = bike
      @search_kind = SearchResults::Container::Component.permitted_search_kind(search_kind)

      # NOTE: passed event_record renders - even if it isn't the current_event_record
      @event_record = event_record || @bike.current_event_record

      # If this is cached (it is by default), don't show the serial for the user
      @is_cached = !skip_cache
      @current_user = current_user unless @is_cached
    end

    def render?
      @bike.present?
    end

    private

    def render_second_column?
      @event_record.present?
    end

    def render_for_sale_info?
      @event_record.is_a?(MarketplaceListing)
    end

    # If for sale, return "For Sale" - otherwise returns price
    def price_span
      return bike_status_span(@bike) if @event_record.for_sale?

      content_tag(:strong, translation(".price"), class: "attr-title")
    end

    def occurred_at_with_fallback
      @bike.occurred_at || @event_record&.updated_at || @bike.updated_at
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
