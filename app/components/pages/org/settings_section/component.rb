# frozen_string_literal: true

module Pages
  module Org
    module SettingsSection
      # A card on the organization settings page: the title and description on the left,
      # the block's fields on the right. Stacks below md.
      class Component < ApplicationComponent
        def initialize(title:, description: nil)
          @title = title
          @description = description
        end
      end
    end
  end
end
