# frozen_string_literal: true

require "ostruct"

module UI
  module CardTable
    class ComponentPreview < ApplicationComponentPreview
      # Narrower than its columns, so the first stays put while the rest scroll under it
      def default
        render_with_template(template: "ui/card_table/component_preview/default", locals: {records: [
          OpenStruct.new(name: "Mothman", region: "West Virginia", credibility: "Medium", sightings: 142),
          OpenStruct.new(name: "Bigfoot", region: "Pacific Northwest", credibility: "Low", sightings: 10000),
          OpenStruct.new(name: "Okapi", region: "Congo", credibility: "Confirmed", sightings: 1)
        ]})
      end
    end
  end
end
