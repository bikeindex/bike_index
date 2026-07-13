# frozen_string_literal: true

module Registrations
  module New
    module Progress
      class Component < ApplicationComponent
        def initialize(step:, total:)
          @step = step
          @total = total
        end
      end
    end
  end
end
