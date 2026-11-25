# frozen_string_literal: true

module Pages
  module Admin
    module CycleTypeDrawings
      # Each cycle type's Bike Book drawing at its typical figures, and of a catalog model of that type. The
      # admin--cycle-type-details controller follows each with its type_details Bike Book draws their own way, whose list is
      # the drawings' own
      class Component < ApplicationComponent
        Row = Data.define(:name, :type, :example_model) do
          def collapsed = example_model.nil? || Pages::Admin::CycleTypeDrawings::Component::COLLAPSED_TYPES.include?(type)
        end

        # by Bike Book vehicle type, those that start collapsed though they have a catalog example
        COLLAPSED_TYPES = %w[non-e-skateboard wheelchair unicycle].freeze

        # by Bike Book vehicle type, or type/type_detail, the catalog model that fills in the most of its drawing
        EXAMPLE_MODELS = {
          "bike" => "m/specialized/2025/aethos-comp-shimano-105-di2-ca",
          "bike/step_through" => "m/aventon/2025/level-3-step-through",
          "bike/bench-seat" => "m/cycrown/2026/run-mini",
          "tandem" => "m/co-motion/2018/kalapuya-shimano-ultegra-r8000-2x11",
          "tandem/step_through" => "m/sun/2025/brickell-tandem-cb-step-thru",
          "unicycle" => "m/nimbus-unicycles/2014/muni-24",
          "tricycle" => "m/sun/2022/miami-sun-traditional-24-step-thru",
          "tricycle/tadpole" => "m/reactive-adaptations/2025/hammerhead",
          "recumbent" => "m/hp-velotechnik/2019/scorpion-fx-20",
          "trailer" => "m/retrospec/2024/rover-plus",
          "wheelchair" => "m/bowhead/2025/era",
          "cargo" => "m/riese-and-muller/2024/load4-60-touring",
          "cargo-rear" => "m/mongoose/2019/envoy-26in",
          "cargo-trike" => "m/sun/2022/atlas-cargo-24-step-thru",
          "trail-behind" => "m/trek/2016/mountain-train-206",
          "e-scooter" => "m/segway/2025/max-g3",
          "personal-mobility" => "m/inmotion/2024/v11y",
          "non-e-scooter" => "m/jetson/2018/flex-wood-2-in-1-scooter",
          "non-e-skateboard" => "m/isinwheel/2024/v10",
          "e-motorcycle" => "m/sur-ron/2024/ultra-bee-r",
          "elliptical" => "m/elliptigo/2022/11r",
          "balance-bike" => "m/strider/2014/12-sport"
        }.freeze

        def initialize(cycle_types:, manifest_url:)
          @rows = cycle_types.map do |cycle_type|
            type = cycle_type.slug.to_s
            Row.new(name: cycle_type.name, type:, example_model: EXAMPLE_MODELS[type])
          end.partition { !it.collapsed }.flatten
          @manifest_url = manifest_url
        end
      end
    end
  end
end
