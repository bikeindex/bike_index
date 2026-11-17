# frozen_string_literal: true

module Atoms
  module RegistrationStep
    class ComponentPreview < ApplicationComponentPreview
      # Every step an e-vehicle registration passes through, in order, with a page for each
      # of the live education course's
      def e_vehicle_steps
        course = ::EducationCourse.active_or_default_for(lookbook_organization)
        page_ids = ::BikeServices::Register.course_pages(course).map(&:id)
        return missing_notice("an education course with pages") if page_ids.none?

        acknowledged = ->(count) { {details_completed: true, education_course: {id: course.id, acknowledged_page_ids: page_ids.first(count)}} }
        b_params = [
          b_param(course, bike: {manufacturer_id: nil}),
          b_param(course),
          b_param(course, bike: {status: "status_stolen"}, details_completed: true),
          *page_ids.each_index.map { b_param(course, **acknowledged.call(it)) },
          b_param(course, **acknowledged.call(page_ids.count)),
          # Left to the owner, so there's no course to agree to before the email confirms the address
          b_param(nil, creator: nil, details_completed: true, register_separate_attestation: true),
          b_param(course, created_bike_id: 42, **acknowledged.call(page_ids.count))
        ]
        render_with_template(template: "atoms/registration_step/preview/e_vehicle_steps", locals: {b_params:})
      end

      private

      def b_param(course, bike: {}, creator: lookbook_user, created_bike_id: nil, **params)
        ::BParam.new(origin: "register_flow", creator_id: creator&.id, created_bike_id:, params: {
          bike: {owner_email: lookbook_user&.email, cycle_type: "e-scooter", manufacturer_id: 12,
                 creation_organization_id: course&.organization_id}.merge(bike),
          **params
        }.as_json)
      end
    end
  end
end
