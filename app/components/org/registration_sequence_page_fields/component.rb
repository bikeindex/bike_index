# frozen_string_literal: true

module Org
  module RegistrationSequencePageFields
    class Component < ApplicationComponent
      def initialize(form_builder:)
        @form_builder = form_builder
      end
    end
  end
end
