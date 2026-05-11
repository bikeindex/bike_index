# frozen_string_literal: true

module UI
  module Modal
    class Component < ApplicationComponent
      renders_one :body

      def initialize(id:, title: nil)
        @id = id
        @title = title
      end
    end
  end
end
