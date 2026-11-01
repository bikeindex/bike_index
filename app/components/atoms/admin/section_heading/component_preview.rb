# frozen_string_literal: true

module Atoms
  module Admin
    module SectionHeading
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Atoms::Admin::SectionHeading::Component.new(title: "Notifications", count: 12, href: "#"))
        end
      end
    end
  end
end
