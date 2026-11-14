# frozen_string_literal: true

module Pages
  module Org
    module EducationCourse
      # A faked walk-through of the registrant flow: one page of rules per screen, paged
      # through with Continue/Back, ending on the acknowledgment review - so an org sees
      # exactly what registrants see. index == pages.count is that review screen.
      module Preview
        class Component < ApplicationComponent
          def initialize(education_course:, index: 0, admin: false)
            @education_course = education_course
            @index = index
            @admin = admin
          end

          def render?
            @education_course.present?
          end

          private

          def pages
            BikeServices::Register.course_pages(@education_course)
          end

          def reviewing?
            @index >= pages.count
          end

          def current_page
            pages[@index]
          end

          # The registration's own steps, so the progress bar matches the real flow. No
          # b_param, so it's the flow without a report - which is what a preview walks
          def progress_flow
            @progress_flow ||= BikeServices::Register.flow(nil, course: @education_course)
          end

          def progress_step
            reviewing? ? "review" : BikeServices::Register.step_for_page_index(@index)
          end

          def acknowledgment_step_count
            BikeServices::Register.acknowledgment_step_count(@education_course)
          end

          def back_path
            @index.zero? ? exit_path : course_path(page: @index)
          end

          # The URL page param is 1-indexed; @index is 0-based
          def page_param(index) = index + 1

          # A GET form appends ?page= from a hidden field, since a form's own query string
          # is dropped on submit
          def course_path(page: nil)
            EducationCoursePaths.preview(@education_course, page:, admin: @admin)
          end

          def exit_path
            EducationCoursePaths.preview_exit(@education_course, admin: @admin)
          end
        end
      end
    end
  end
end
