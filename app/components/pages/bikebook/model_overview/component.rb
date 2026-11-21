# frozen_string_literal: true

module Pages
  module Bikebook
    module ModelOverview
      # A catalog model's photo and headline fields, as the browser's Overview has them, for a browser without
      # JavaScript. vocabulary is Integrations::Bikebook::Catalog.vocabulary, without which it renders nothing
      class Component < ApplicationComponent
        def initialize(model:, vocabulary:)
          @model = model
          @vocabulary = vocabulary
        end

        def render? = @vocabulary.present?

        def title = [@model["manufacturer"], @model["model"]].compact_blank.join(" ")

        private

        def named(field, value) = @vocabulary.dig("names", field, value) || value

        def years = @model["years"].to_h.sort.reverse.map(&:last)

        def year_range
          first, final = @model.values_at("first_year", "final_year")
          return if first.blank?

          (first == final) ? first : "#{first} – #{final || translation(".current")}"
        end

        # The newest year's page still on the manufacturer's site, rather than an archived one
        def manufacturer_url = years.find { it["url_live"] && it["url"].present? }&.dig("url")

        def price
          year = years.find { it["original_msrp"].is_a?(Numeric) } or return
          code = year["original_msrp_currency"] || "USD"
          currency = @vocabulary.dig("currencies", code) || {}
          amount = year["original_msrp"].fdiv(Money::Currency.find(code)&.subunit_to_unit || 100)
          tag.span(safe_join([tag.span(currency["symbol"] || "#{code} ", title: currency["name"] || code),
            helpers.number_display((amount % 1).zero? ? amount.to_i : amount)]))
        end

        def vehicle_type
          step_through = translation(".step_through") if @model.dig("frame", "top_tube").to_s.match?(/\Astep[_-]through\z/i)
          [*%w[type type_detail].filter_map { named(it, @model[it]).presence }, step_through].compact.join(" · ")
        end

        def frame_material
          material = @model.dig("frame", "material").presence or return
          detail = @model.dig("frame", "material_detail")
          safe_join([named("frame.material", material), (tag.span(detail, class: "tw:text-xs less-strong") if detail.present?)].compact, " ")
        end

        def e_vehicle_classes = EbikeRuleServices::BikebookVehicles.stock_classifications(@model)
          .map { @vocabulary.dig("classifications", it) || named("motors.operating_modes.e_vehicle_classifications", it) }.join(", ")
      end
    end
  end
end
