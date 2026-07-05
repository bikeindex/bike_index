# frozen_string_literal: true

module Org
  module RegistrationSequence
    # One editable bullet row in PageEdit's list. Rendered per existing bullet, and once with
    # index "__INDEX__" inside the <template> the bullet-editors controller clones on "Add bullet".
    module PageEditBullet
      class Component < ApplicationComponent
        def initialize(index:, value: "")
          @index = index
          @value = value
        end

        private

        # Throwaway builder: its field submits under an unpermitted `bullet` param (ignored by the
        # backend); the JS controller recombines the bullets into the page's body on change/submit.
        def bullet_builder
          BikeIndexFormBuilder.new("bullet[#{@index}]", nil, helpers, {})
        end
      end
    end
  end
end
