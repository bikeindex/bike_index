# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module Photo
        # A photo the photo step stored, filling its shot's tile - the photos endpoint answers with it too
        class Component < ApplicationComponent
          def initialize(public_image:)
            @public_image = public_image
          end
        end
      end
    end
  end
end
