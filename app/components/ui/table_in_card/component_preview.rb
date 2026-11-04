# frozen_string_literal: true

module UI
  module TableInCard
    class ComponentPreview < ApplicationComponentPreview
      # selection_column labels each checkbox from its record's model_name
      Cryptid = Data.define(:id, :name, :region, :credibility, :sightings) { extend ActiveModel::Naming }

      # @!group Variants

      # Narrower than its columns, so the first stays put while the rest scroll under it
      def default
        render_with_template(template: "ui/table_in_card/component_preview/default", locals: {records: sample_records.first(3)})
      end

      # Shift-click a checkbox to give every one since the last clicked its state
      def selection
        render_with_template(template: "ui/table_in_card/component_preview/selection", locals: {records: sample_records})
      end

      # @!endgroup

      private

      def sample_records
        [
          Cryptid.new(id: 1, name: "Mothman", region: "West Virginia", credibility: "Medium", sightings: 142),
          Cryptid.new(id: 2, name: "Bigfoot", region: "Pacific Northwest", credibility: "Low", sightings: 10000),
          Cryptid.new(id: 3, name: "Okapi", region: "Congo", credibility: "Confirmed", sightings: 1),
          Cryptid.new(id: 4, name: "Nessie", region: "Scottish Highlands", credibility: "Low", sightings: 1036),
          Cryptid.new(id: 5, name: "Chupacabra", region: "Puerto Rico", credibility: "Low", sightings: 87)
        ]
      end
    end
  end
end
