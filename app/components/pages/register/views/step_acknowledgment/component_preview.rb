# frozen_string_literal: true

module Pages
  module Register
    module Views
      module StepAcknowledgment
        # One page of an organization's e-vehicle rules, rendered from its live course
        class ComponentPreview < ApplicationComponentPreview
          # Where the flow explains why these pages appeared at all
          # @label Step 1 of 4
          def step_1_of_4
            acknowledgment_page(0)
          end

          # The last of the rule pages, with only the review left after it
          # @label Step 3 of 4
          def step_3_of_4
            acknowledgment_page(2)
          end

          # Revisited from the review, showing what was agreed to rather than asking again
          def already_acknowledged
            acknowledgment_page(0, acknowledged: true)
          end

          private

          def acknowledgment_page(index, acknowledged: false)
            return production_notice("registration") if Rails.env.production?

            course = preview_course
            page = ::BikeServices::Register.course_pages(course)[index]
            return missing_notice("an education course with #{index + 1} pages") if page.blank?

            b_param = preview_b_param(course, acknowledged ? [page.id] : [])
            render(Pages::Register::Views::StepAcknowledgment::Component.new(course:, b_param:,
              step: ::BikeServices::Register.step_for_page_index(index),
              flow: ::BikeServices::Register.flow(b_param, course:)))
          end

          # The pages only appear for an e-vehicle registered with the organization
          def preview_b_param(course, acknowledged_page_ids)
            ::BParam.new(origin: "register_flow", params: {
              bike: {owner_email: lookbook_user&.email, cycle_type: "e-scooter",
                     creation_organization_id: course.organization_id},
              education_course: {id: course.id, acknowledged_page_ids:}
            }.as_json)
          end

          # The live default course stands in where no organization has activated a course
          def preview_course = ::EducationCourse.active_or_default_for(lookbook_organization)
        end
      end
    end
  end
end
