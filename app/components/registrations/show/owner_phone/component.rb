# frozen_string_literal: true

module Registrations
  module Show
    module OwnerPhone
      class Component < ApplicationComponent
        def initialize(phone: nil)
          @phone = phone
        end

        def render?
          @phone.present?
        end
      end
    end
  end
end
