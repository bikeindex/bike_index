# frozen_string_literal: true

module Pages
  module Org
    module EducationCourse
      module Edit
        # The drag-to-reorder page list and the sequence-wide settings form.
        class Component < ApplicationComponent
          def initialize(education_course:, admin: false)
            @education_course = education_course
            @admin = admin
            @editable = education_course.draft?
          end

          private

          def pages
            @pages ||= @education_course.education_course_pages.to_a
          end

          def new_page_path = EducationCoursePaths.new_page(@education_course, admin: @admin)

          def sequence_path = EducationCoursePaths.sequence(@education_course, admin: @admin)
        end
      end
    end
  end
end
