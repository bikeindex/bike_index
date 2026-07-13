# frozen_string_literal: true

module Registrations
  module New
    module Heading
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Registrations::New::Heading::Component.new(title: "Register your bike!",
            subtitle: "Just the essentials to start."))
        end
      end
    end
  end
end
