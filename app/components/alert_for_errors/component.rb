# frozen_string_literal: true

module AlertForErrors
  class Component < ApplicationComponent
    def initialize(object:, name: nil, error_messages: nil, dismissable: false)
      @object = object
      @name = name || @object.class.name.titleize
      @error_messages ||= @object.errors.full_messages
      @dismissable = dismissable
    end

    def render?
      @error_messages.any?
    end

    private

    def header_text
      translation(".errors_prevented_this_from_being_saved", errors_count: @error_messages.count,
        object_name: @name)
    end
  end
end
