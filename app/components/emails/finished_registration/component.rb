# frozen_string_literal: true

module Emails::FinishedRegistration
  class Component < ApplicationComponent
    def initialize(ownership:)
      @ownership = ownership
    end
  end
end
