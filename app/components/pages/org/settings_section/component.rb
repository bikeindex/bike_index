# frozen_string_literal: true

module Pages
  module Org
    module SettingsSection
      class Component < ApplicationComponent
        def initialize(title:, description:)
          @title = title
          @description = description
        end
      end
    end
  end
end
