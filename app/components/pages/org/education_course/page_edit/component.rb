# frozen_string_literal: true

module Pages
  module Org
    module EducationCourse
      module PageEdit
        class Component < ApplicationComponent
          def initialize(form_builder:)
            @form_builder = form_builder
          end

          private

          # One editable row per bullet, with an empty row so a blank page has somewhere to type
          def bullets
            @form_builder.object.bullets.presence || [""]
          end

          # There's no badge to name until the page belongs to a course
          def badge_name = @form_builder.object.education_course&.badge_name
        end
      end
    end
  end
end
