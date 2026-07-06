# frozen_string_literal: true

module RegistrationShow
  module ComponentList
    # The bike's components, grouped by Cgroup — mirrors the legacy show page
    class Component < ApplicationComponent
      def initialize(bike:)
        @bike = bike
      end

      def render?
        components.any?
      end

      private

      def components
        @components ||= @bike.components
      end

      def grouped_components
        Cgroup.commonness.filter_map do |cgroup|
          matching = components.select { |component| component.cgroup_id == cgroup.id }
          [cgroup, matching] if matching.any?
        end
      end

      def component_label(component)
        position = if component.front && component.rear
          t("bikes.main_show_block.front_rear")
        elsif component.front
          t("bikes.main_show_block.front")
        elsif component.rear
          t("bikes.main_show_block.rear")
        else
          ""
        end

        if component.component_type == "unknown"
          position + t("bikes.main_show_block.other")
        elsif component.component_type.present?
          [position, component.component_type.titleize].reject(&:blank?).join(" ")
        else
          position
        end
      end

      def component_value(component)
        parts = [component.description, component.component_model].reject(&:blank?)
        parts << t("bikes.main_show_block.componentyear", componentyear: component.year) if component.year.present?
        parts << "(#{component.mnfg_name})" if component.mnfg_name.present?
        parts.any? ? parts.join(" ") : t("bikes.main_show_block.component_no_info")
      end
    end
  end
end
