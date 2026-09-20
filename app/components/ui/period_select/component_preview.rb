# frozen_string_literal: true

module UI
  module PeriodSelect
    class ComponentPreview < ApplicationComponentPreview
      # @!group Period Select Variants
      def default
        placed(UI::PeriodSelect::Component.new(
          period: "all",
          start_time: ::Time.current - 1.year,
          end_time: ::Time.current
        ))
      end

      def custom_selected
        placed(UI::PeriodSelect::Component.new(
          period: "custom",
          start_time: ::Time.current - 1.day,
          end_time: ::Time.current
        ))
      end

      def with_include_future
        placed(UI::PeriodSelect::Component.new(
          include_future: true,
          period: "next_week",
          start_time: ::Time.current,
          end_time: ::Time.current + 7.days
        ))
      end

      # The periods as another form's radios, which submit it rather than navigating
      def in_form
        render_with_template(template: "ui/period_select/preview/in_form",
          locals: {component: UI::PeriodSelect::Component.new(
            period: "week",
            start_time: ::Time.current - 1.week,
            end_time: ::Time.current,
            form: "period_preview_form"
          )})
      end
      # @endgroup

      private

      def placed(component)
        render_with_template(template: "ui/period_select/preview/placed", locals: {component:})
      end
    end
  end
end
