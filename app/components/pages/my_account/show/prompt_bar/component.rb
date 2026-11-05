# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module PromptBar
        # The quiet row under the registrations: an icon disc, a title with a line of
        # explanation, and the one action it asks for
        #
        # icon_classes: the disc's background and icon color
        class Component < ApplicationComponent
          renders_one :icon
          renders_one :title
          renders_one :subtext
          renders_one :action

          def initialize(icon_classes:)
            @icon_classes = icon_classes
          end
        end
      end
    end
  end
end
