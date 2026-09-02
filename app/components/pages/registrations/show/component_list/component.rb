# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ComponentList
        # The bike's full spec sheet — component records plus the bike's own spec
        # attributes (wheel/tire sizes, drivetrain, …), grouped by Cgroup into cards.
        # collapsed: renders the spec sheet closed by default (org admin view)
        class Component < ApplicationComponent
          def initialize(bike:, collapsed: false)
            @bike = bike
            @collapsed = collapsed
          end

          def render?
            grouped_rows.any?
          end

          private

          def components
            @components ||= @bike.components
          end

          # [cgroup, rows] pairs (highest cgroup priority first, frame and fork leads),
          # each row a [label, value]. The bike's own spec attributes for a group (e.g.
          # wheel/tire sizes in Wheels) lead the group's component rows.
          def grouped_rows
            @grouped_rows ||= Cgroup.reorder(priority: :desc, name: :asc).filter_map do |cgroup|
              rows = (spec_attribute_rows(cgroup.slug) + component_rows(cgroup)).select { |_label, value| value.present? }
              [cgroup, rows] if rows.any?
            end
          end

          def component_rows(cgroup)
            components.select { |component| component.cgroup_id == cgroup.id }
              .map { |component| [component_label(component), component_value(component)] }
          end

          # Bike attributes the legacy show page lists that aren't in the bike details card
          def spec_attribute_rows(slug)
            case slug
            when "wheels" then wheel_rows
            when "drivetrain" then drivetrain_rows
            when "frame-and-fork" then frame_rows
            else []
            end
          end

          def wheel_rows
            return [] if @bike.front_wheel_size_id.blank?

            same_width = @bike.front_tire_narrow.nil? || @bike.front_tire_narrow == @bike.rear_tire_narrow
            if @bike.front_wheel_size_id == @bike.rear_wheel_size_id && same_width
              [wheel_row("wheel_diameter", @bike.front_wheel_size), tire_row("tire_width", @bike.front_tire_narrow)]
            else
              [wheel_row("front_wheel_diameter", @bike.front_wheel_size), tire_row("front_tire_width", @bike.front_tire_narrow),
                wheel_row("rear_wheel_diameter", @bike.rear_wheel_size), tire_row("rear_tire_width", @bike.rear_tire_narrow)]
            end.compact
          end

          def wheel_row(key, wheel_size)
            [translation(".#{key}"), wheel_size&.name]
          end

          def tire_row(key, narrow)
            return nil if narrow.nil?

            [translation(".#{key}"), translation(".tire_width_narrow_#{narrow}")]
          end

          def drivetrain_rows
            rows = if @bike.fixed_gear?
              [[translation(".drivetrain"), translation(".drivetrain_fixed")]]
            else
              [[translation(".drivetrain"), @bike.drivetrain_attributes],
                [translation(".drivetrain_front"), @bike.front_gear_type&.name],
                [translation(".drivetrain_rear"), @bike.rear_gear_type&.name]]
            end
            rows << [translation(".propulsion_type"), @bike.propulsion_type] unless @bike.propulsion_type == "foot-pedal"
            rows
          end

          def frame_rows
            return [] unless BikeServices::Displayer.paint_description?(@bike)

            [[translation(".paint_description"), @bike.paint_description]]
          end

          # Teaser subtitle listing the spec groups present
          def spec_hint
            grouped_rows.map { |cgroup, _| cgroup.name }.to_sentence
          end

          def component_label(component)
            position = if component.front && component.rear
              translation(".front_rear")
            elsif component.front
              translation(".front")
            elsif component.rear
              translation(".rear")
            else
              ""
            end

            if component.component_type == "unknown"
              position + translation(".other")
            elsif component.component_type.present?
              [position, component.component_type.titleize].reject(&:blank?).join(" ")
            else
              position
            end
          end

          def component_value(component)
            parts = [component.description, component.component_model].reject(&:blank?)
            parts << translation(".componentyear", componentyear: component.year) if component.year.present?
            parts << "(#{component.mnfg_name})" if component.mnfg_name.present?
            parts.any? ? parts.join(" ") : translation(".component_no_info")
          end
        end
      end
    end
  end
end
