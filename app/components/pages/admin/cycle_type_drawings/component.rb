# frozen_string_literal: true

module Pages
  module Admin
    module CycleTypeDrawings
      # Each cycle type's Bikebook drawing at its typical figures, and of a catalog model of that type, followed by
      # its type_details that Bikebook draws their own way
      class Component < ApplicationComponent
        Row = Data.define(:name, :type, :type_detail, :example_model, :collapsed) do
          # the URL param a collapsed row opens from
          def param = [type, type_detail].compact.join("_")
        end

        # by Bikebook vehicle type, those that start collapsed though they have a catalog example
        COLLAPSED_TYPES = %w[skateboard wheelchair unicycle].freeze

        # the CycleType slugs Bikebook's vehicle types name differently
        BIKEBOOK_TYPES = {
          trailer: "bike_trailer",
          cargo: "cargo_bike",
          "cargo-rear": "cargo_bike_rear",
          "cargo-trike": "cargo_tricycle",
          "cargo-trike-rear": "cargo_tricycle_rear",
          "personal-mobility": "epamd",
          "non-e-scooter": "scooter",
          "non-e-skateboard": "skateboard",
          elliptical: "elliptical_bike"
        }.freeze

        # by Bikebook vehicle type
        TYPE_DETAILS = {"bike" => %w[step_through bench_seat], "tricycle" => %w[tadpole]}.freeze

        # by Bikebook vehicle type, or type/type_detail, the catalog model that fills in the most of its drawing
        EXAMPLE_MODELS = {
          "bike" => "m/specialized/2025/aethos_comp_shimano_105_di2_ca",
          "bike/step_through" => "m/aventon/2025/level_3_step_through",
          "bike/bench_seat" => "m/cycrown/2026/run_mini",
          "tandem" => "m/co_motion/2018/kalapuya_shimano_ultegra_r8000_2x11",
          "unicycle" => "m/nimbus_unicycles/2014/muni_24",
          "tricycle" => "m/sun/2022/miami_sun_traditional_24_step_thru",
          "tricycle/tadpole" => "m/reactive_adaptations/2025/hammerhead",
          "recumbent" => "m/hp_velotechnik/2019/scorpion_fx_20",
          "bike_trailer" => "m/retrospec/2024/rover_plus",
          "wheelchair" => "m/bowhead/2025/era",
          "cargo_bike" => "m/riese_and_muller/2024/load4_60_touring",
          "cargo_bike_rear" => "m/mongoose/2019/envoy_26in",
          "cargo_tricycle" => "m/sun/2022/atlas_cargo_24_step_thru",
          "trail_behind" => "m/trek/2016/mountain_train_206",
          "e_scooter" => "m/segway/2025/max_g3",
          "epamd" => "m/inmotion/2024/v11y",
          "scooter" => "m/jetson/2018/flex_wood_2_in_1_scooter",
          "skateboard" => "m/isinwheel/2024/v10",
          "e_motorcycle" => "m/sur_ron/2024/ultra_bee_r",
          "elliptical_bike" => "m/elliptigo/2022/11r",
          "balance_bike" => "m/strider/2014/12_sport"
        }.freeze

        def initialize(cycle_types:, manifest_url:)
          # the collapsed rows, those with no catalog example and COLLAPSED_TYPES, last
          @rows = cycle_types.flat_map do |cycle_type|
            type = BIKEBOOK_TYPES[cycle_type.slug] || cycle_type.slug.to_s.underscore
            [nil, *TYPE_DETAILS[type]].map do |type_detail|
              example_model = EXAMPLE_MODELS[[type, type_detail].compact.join("/")]
              Row.new(name: cycle_type.name, type:, type_detail:, example_model:, collapsed: example_model.nil? || COLLAPSED_TYPES.include?(type))
            end
          end.partition { !it.collapsed }.flatten
          @manifest_url = manifest_url
        end
      end
    end
  end
end
