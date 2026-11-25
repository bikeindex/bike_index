# frozen_string_literal: true

module Atoms
  module RegistrationDates
    # @label Registration dates
    class ComponentPreview < ApplicationComponentPreview
      # @label in a wide row, then a narrow one
      def default
        render_with_template(template: "atoms/registration_dates/component_preview/default",
          locals: {bike: ::Bike.new(created_at: Time.current - 400.days, updated_by_user_at: Time.current - 3.days)})
      end
    end
  end
end
