# frozen_string_literal: true

module SharedBlocks
  module SystemColorScheme
    class Component < ApplicationComponent
      def initialize(user:)
        @user = user
      end

      def render? = @user&.color_scheme_system?
    end
  end
end
