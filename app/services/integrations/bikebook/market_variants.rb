# frozen_string_literal: true

module Integrations
  module Bikebook
    # From schema 1.1.0, a market's model sits in its home market's record, under `market_variants` keyed by the market
    # suffixing its id ("CA" is m/specialized/2025/haul_st_ca, from 2.0.0 m/specialized/2025/haul-st-ca), as what
    # differs from it. Before, it's a record of its own.
    # catalog_worker.js expands them the same way
    module MarketVariants
      extend Functionable

      KEY = "market_variants"
      # An array of these merges item by item, keyed by each item's values for them (an empty list by position); any
      # other array is replaced whole
      IDENTITIES = {
        "colorways" => %w[name], "components" => %w[type position type_detail], "motors" => [],
        "operating_modes" => %w[mode availability markets], "sizes" => %w[name], "mounts" => %w[type],
        "wheels" => %w[position bsd], "brakes" => %w[position]
      }.freeze

      # A block's models by id, each market variant's beside its home market's
      def expand(models)
        models.flat_map do |id, record|
          home = record.except(KEY)
          variants = record[KEY].to_h.map do |market, changes|
            variant_id = "#{id}#{(record["schema_version"].to_i >= 2) ? "-" : "_"}#{market.downcase}"
            [variant_id, merge(home, changes).merge("id" => variant_id)]
          end
          [[id, home], *variants]
        end.to_h
      end

      #
      # private below here
      #

      # false removes an object the home market's has (a year's record, a wheel), null any other value
      def merge(base, changes)
        changes.each_with_object(base.dup) do |(key, value), merged|
          if value.nil? || (value == false && merged[key].is_a?(Hash)) then merged.delete(key)
          elsif value.is_a?(Hash) && merged[key].is_a?(Array) then merged[key] = merge(keyed(key, merged[key]), value).values
          elsif value.is_a?(Hash) && merged[key].is_a?(Hash) then merged[key] = merge(merged[key], value)
          else merged[key] = value
          end
        end
      end

      def keyed(key, items)
        fields = IDENTITIES.fetch(key)
        items.each_with_index.to_h do |item, index|
          [fields.empty? ? index.to_s : fields.filter_map { Array(item[it]).join("+").presence }.join(" "), item]
        end
      end

      conceal :merge, :keyed
    end
  end
end
