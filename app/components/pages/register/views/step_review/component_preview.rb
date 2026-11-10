# frozen_string_literal: true

module Pages
  module Register
    module Views
      module StepReview
        # The acknowledgment the rule pages end at, rendered from an organization's live course
        class ComponentPreview < ApplicationComponentPreview
          def default
            return production_notice("registration") if Rails.env.production?

            course = preview_course
            pages = ::BikeServices::Register.course_pages(course)
            return missing_notice("an education course with pages") if pages.none?

            b_param = preview_b_param(course, pages.map(&:id))
            render(Pages::Register::Views::StepReview::Component.new(course:, b_param:, current_user: lookbook_user,
              flow: ::BikeServices::Register.flow(b_param, course:)))
          end

          private

          # Every page acknowledged - the review is only reachable once they all are
          def preview_b_param(course, acknowledged_page_ids)
            ::BParam.new(origin: "register_flow", params: {
              bike: {owner_email: lookbook_user&.email, cycle_type: "e-scooter",
                     creation_organization_id: course.organization_id},
              education_course: {id: course.id, acknowledged_page_ids:}
            }.as_json)
          end

          # The live template stands in where no organization has activated a course
          def preview_course = ::EducationCourse.active_or_template_for(lookbook_organization)
        end
      end
    end
  end
end
