# frozen_string_literal: true

module Registrations
  module New
    module Heading
      class Component < ApplicationComponent
        def initialize(title:, subtitle:)
          @title = title
          @subtitle = subtitle
        end
      end
    end
  end
end
