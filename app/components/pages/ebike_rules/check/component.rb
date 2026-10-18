# frozen_string_literal: true

module Pages
  module EbikeRules
    module Check
      # The frame a check loads into, which is all a frame request renders
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-check"

        def initialize(lookup:, page_title:)
          @lookup = lookup
          @page_title = page_title
        end

        def call
          # its links (register, the BikeBook entry) leave the page; only the lookup loads a check into it
          helpers.turbo_frame_tag(FRAME_ID, class: "tw:block", target: "_top") do
            # A frame response's layout has no title, and the state's is in this one
            # a picked model's details, which the browser copies into the details panel
            safe_join([tag.span(hidden: true, data: {page_title: @page_title, bike_details: @lookup.details.to_json}),
              (render(Pages::EbikeRules::Results::Component.new(lookup: @lookup)) if @lookup.result?), outside_us_note].compact)
          end
        end

        private

        def outside_us_note
          place = @lookup.place
          return if place.nil? || EbikeRuleServices::Places.checks?(place) || EbikeRuleServices::Places::CHECKED_COUNTRIES.include?(place[:code])

          tag.p(translation(".outside_checked_countries", place: place[:name]), class: "#{Pages::EbikeRules::Show::Component::SECTION_CLASSES} tw:mt-6 " \
            "tw:text-[15px] tw:text-gray-700 tw:dark:text-gray-300")
        end
      end
    end
  end
end
