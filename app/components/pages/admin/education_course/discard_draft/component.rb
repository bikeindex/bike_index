# frozen_string_literal: true

module Pages
  module Admin
    module EducationCourse
      module DiscardDraft
        # Throwing the draft away, at the bottom of every admin course screen - away from
        # the header's actions, which all keep it
        class Component < ApplicationComponent
          def initialize(education_course:)
            @education_course = education_course
          end

          def render? = @education_course.draft?

          private

          def discard_path = EducationCoursePaths.course(@education_course, admin: true)

          def confirm_text = ::EducationCourse::DISCARD_DRAFT_CONFIRM
        end
      end
    end
  end
end
