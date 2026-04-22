# frozen_string_literal: true

module Emails
  module Partials
    module BikeBox
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Emails::Partials::BikeBox::Component.new(bike:, ownership:, bike_url_path:))
        end
      end
    end
  end
end
