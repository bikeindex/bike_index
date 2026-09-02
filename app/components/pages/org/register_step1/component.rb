# frozen_string_literal: true

# TODO: #4185 - remove this component when removing the legacy org new bike iframe

module Pages
  module Org
    module RegisterStep1
      # The register flow's opening step on an organization's own page, with the way
      # back to the embed form it replaces
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, organization:, current_user: nil)
          @b_param = b_param
          @steps = steps
          @organization = organization
          @current_user = current_user
        end
      end
    end
  end
end
