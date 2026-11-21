# frozen_string_literal: true

module Integrations
  module Bikebook
    # A Bike Book model's stock specs, as the bike and component params registration takes
    module Data
      extend Functionable

      # nil for a model the catalog lacks, or while it doesn't answer. market is a country's ISO code, for its variant
      def get_model(options)
        if options.is_a?(Bike)
          options = {manufacturer: options.manufacturer&.name, year: options.year, frame_model: options.frame_model,
                     market: options.address_record&.country_iso}
        end
        return unless options.values_at(:manufacturer, :year, :frame_model).all?(&:present?)

        year = options[:year].to_i
        id = BikebookModel.catalog_id_for(manufacturer: options[:manufacturer], name: options[:frame_model], year:,
          market: options[:market])
        record = id && Integrations::Bikebook::Catalog.block_models(id)&.dig(id)
        record && {bike: bike_attributes(record, year), components: component_attributes(record)}.with_indifferent_access
      end

      #
      # private below here
      #

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
        vocabulary = Integrations::Bikebook::Catalog.manifest&.dig("vocabulary")
        names = vocabulary && Integrations::Bikebook::Catalog.file(vocabulary)&.dig("names", "components.type")
        record["components"].to_a.map do |component|
          position = Array(component["position"])
          type = Integrations::Bikebook::Catalog.current_slug(component["type"])
          {component_type: names&.dig(type) || type&.humanize, description: component["description"],
           manufacturer: component["manufacturer"], front: position.include?("front"), rear: position.include?("rear")}
        end
      end

      conceal :bike_attributes, :component_attributes
    end
  end
end
