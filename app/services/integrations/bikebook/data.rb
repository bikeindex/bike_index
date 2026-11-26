# frozen_string_literal: true

module Integrations
  module Bikebook
    # A Bike Book model's stock specs, as the bike and component params registration takes
    module Data
      extend Functionable

      # The specification's bike and component params, nil for a model the catalog lacks or while it doesn't answer
      def get_model(specification, year:)
        specification&.bikebook_data && {bike: specification.bikebook_data_bike_attributes(year:),
                                         components: specification.bikebook_data_component_attributes}.with_indifferent_access
      rescue Integrations::Bikebook::Catalog::Unreachable
        nil
      end

      # A bike's own, or unsaved: the manufacturer's `bikebook_model`, a catalog id or citation key picked in registration,
      # else its model matching frame_model and year. nil without a year. market is a country's ISO code, which a citation
      # key's market overrides
      def vehicle_specification(options)
        if options.is_a?(Bike)
          return options.vehicle_specification || vehicle_specification(manufacturer_id: options.manufacturer_id, year: options.year,
            frame_model: options.frame_model, market: options.address_record&.country_iso)
        end
        return unless options.values_at(:manufacturer_id, :year).all?(&:present?)

        market = Integrations::Bikebook::Catalog.market(options[:market])
        bikebook_models = BikebookModel.where(manufacturer_id: options[:manufacturer_id])
        VehicleSpecification.cited(options[:bikebook_model], market:, bikebook_models:) ||
          matching(options, market)&.then { VehicleSpecification.new(bikebook_model: it, bikebook_market: market) }
      end

      def bike_attributes(record, year)
        colorways = record.dig("years", year.to_s, "colorways").to_a
        colorway = colorways.first if colorways.one?
        {
          cycle_type: CycleType.find_sym(record["type"])&.to_s,
          paint_description: colorway&.dig("name"),
          description: record["description"],
          rear_wheel_bsd: record["wheels"]&.find { it["position"]&.include?("rear") }&.dig("bsd"),
          stock_photo_url: colorway&.dig("stock_photo") || record["stock_photo"]
        }
      end

      # A component's type by the name its Ctype has
      def component_attributes(record)
        names = Integrations::Bikebook::Catalog.vocabulary_dig("names", "components.type")
        record["components"].to_a.map do |component|
          position = Array(component["position"])
          {component_type: names&.dig(component["type"]) || component["type"]&.humanize, description: component["description"],
           manufacturer: component["manufacturer"], front: position.include?("front"), rear: position.include?("rear")}
        end
      end

      #
      # private below here
      #

      def matching(options, market)
        return if options[:frame_model].blank?

        Integrations::Bikebook::ModelSearch.matching(manufacturer_id: options[:manufacturer_id], name: options[:frame_model], year: options[:year].to_i, market:)
      end

      conceal :matching
    end
  end
end
