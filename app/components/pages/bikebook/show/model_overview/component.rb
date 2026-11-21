# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      module ModelOverview
        # A catalog model's photo and headline fields, as the browser's Overview has them, for a browser without JavaScript
        class Component < ApplicationComponent
          def initialize(model:, vocabulary:)
            @model = model
            @vocabulary = vocabulary
          end

          private

          def title = [@model["manufacturer"], @model["model"]].compact_blank.join(" ")

          def named(field, value) = @vocabulary.dig("names", field, value) || value

          # Newest first
          def years = @model["years"].to_h.sort_by { -it.first.to_i }.map(&:last)

          def year_range
            first, final = @model.values_at("first_year", "final_year")
            return if first.blank?

            (first == final) ? first.to_s : "#{first} – #{final || translation(".current")}"
          end

          # The newest year's page still on the manufacturer's site, rather than an archived one
          def manufacturer_url = years.find { it["url_live"] && it["url"].present? }&.dig("url")

          def price
            year = years.find { it["original_msrp"].is_a?(Numeric) } or return
            code = year["original_msrp_currency"] || "USD"
            currency = @vocabulary.dig("currencies", code) || {}
            amount = year["original_msrp"].fdiv(100)
            tag.span(safe_join([tag.span(currency["symbol"] || "#{code} ", title: currency["name"] || code),
              helpers.number_display((amount % 1).zero? ? amount.to_i : amount)]))
          end

          def vehicle_type = %w[type type_detail].filter_map { named(it, @model[it]).presence }.join(" · ").presence

          def frame_material
            material = @model.dig("frame", "material").presence or return
            detail = @model.dig("frame", "material_detail")
            safe_join([named("frame.material", material), (tag.span(detail, class: "tw:text-xs less-strong") if detail.present?)].compact, " ")
          end

          # The classifications the modes it's sold with have, as BikebookVehicles' stock? has them
          def e_vehicle_classes
            modes = Array(@model["motors"]).flat_map { Array(it["operating_modes"]) }
              .select { [nil, "stock", "app_update"].include?(it["availability"]) }
            modes.flat_map { Array(it["e_vehicle_classifications"]) }.uniq
              .map { @vocabulary.dig("e_vehicle_classifications", it, "name") || named("motors.operating_modes.e_vehicle_classifications", it) }
              .join(", ").presence
          end
        end
      end
    end
  end
end
