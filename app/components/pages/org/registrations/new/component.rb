# frozen_string_literal: true

module Pages
  module Org
    module Registrations
      module New
        # The register flow's opening page on an organization's own page, with a link below
        # it to the settings that change its shape
        class Component < ApplicationComponent
          def initialize(b_param:, flow:, organization:, current_user: nil, motorized_review: false)
            @b_param = b_param
            @flow = flow
            @organization = organization
            @current_user = current_user
            @motorized_review = motorized_review
          end
        end
      end
    end
  end
end
