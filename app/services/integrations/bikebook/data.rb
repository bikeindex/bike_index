# frozen_string_literal: true

module Integrations
  module Bikebook
    # A Bike Book model's stock specs, as the bike and component params registration takes
    module Data
      extend Functionable

      # nil for a model the catalog lacks, or while it doesn't answer
      def get_model(options)
        options = {manufacturer: options.manufacturer&.name, year: options.year, frame_model: options.frame_model} if options.is_a?(Bike)
        return unless options.values_at(:manufacturer, :year, :frame_model).all?(&:present?)

        year = options[:year].to_i
        id = Integrations::Bikebook::Catalog.model_id(manufacturer: options[:manufacturer], name: options[:frame_model], year:)
        record = id && Integrations::Bikebook::Catalog.model(id)
        record && {bike: bike_attributes(record, year), components: component_attributes(record)}.with_indifferent_access
      end

      #
      # private below here
      #

      def bike_attributes(record, year)
        colorways = record.dig("years", year.to_s, "colorways").to_a
        colorway = colorways.first if colorways.one?
        {
          cycle_type: CycleType.find_sym(Integrations::Bikebook::Catalog::CYCLE_TYPES.key(record["type"]) || record["type"])&.to_s,
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
          {component_type: names&.dig(component["type"]) || component["type"]&.humanize, description: component["description"],
           manufacturer: component["manufacturer"], front: position.include?("front"), rear: position.include?("rear")}
        end
      end

      conceal :bike_attributes, :component_attributes
    end
  end
end
