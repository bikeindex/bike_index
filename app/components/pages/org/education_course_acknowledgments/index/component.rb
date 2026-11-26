# frozen_string_literal: true

module Pages
  module Org
    module EducationCourseAcknowledgments
      module Index
        # Everyone who completed an education course for one of the organization's e-vehicles
        class Component < ApplicationComponent
          def initialize(pagy:, acknowledgments:, organization:, sort_state:)
            @pagy = pagy
            @acknowledgments = acknowledgments
            @organization = organization
            @sort_state = sort_state
          end
        end
      end
    end
  end
end
