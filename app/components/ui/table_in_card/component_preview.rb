# frozen_string_literal: true

require "ostruct"

module UI
  module TableInCard
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # Narrower than its columns, so the first stays put while the rest scroll under it
      def default
        render_with_template(template: "ui/table_in_card/component_preview/default", locals: {records: [
          OpenStruct.new(name: "Mothman", region: "West Virginia", credibility: "Medium", sightings: 142),
          OpenStruct.new(name: "Bigfoot", region: "Pacific Northwest", credibility: "Low", sightings: 10000),
          OpenStruct.new(name: "Okapi", region: "Congo", credibility: "Confirmed", sightings: 1)
        ]})
      end

      # Shift-click a checkbox to give every one since the last clicked its state
      def selection
        records = %w[Mothman Bigfoot Okapi Nessie Chupacabra].map.with_index(1) do |name, id|
          OpenStruct.new(id:, name:, model_name: OpenStruct.new(human: "Cryptid"))
        end
        render_with_template(template: "ui/table_in_card/component_preview/selection", locals: {records:})
      end

      # @!endgroup
    end
  end
end
