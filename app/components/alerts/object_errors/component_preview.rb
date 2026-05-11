# frozen_string_literal: true

module Alerts
  module ObjectErrors
    class ComponentPreview < ApplicationComponentPreview
      def default
        user = User.new
        user.errors.add(:email, "can't be blank")
        user.errors.add(:password, "is too short")
        render(Alerts::ObjectErrors::Component.new(object: user))
      end
    end
  end
end
