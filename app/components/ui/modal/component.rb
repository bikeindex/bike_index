# frozen_string_literal: true

module UI
  module Modal
    class Component < ApplicationComponent
      renders_one :body

      # open: render the dialog already open, for a modal the server decided to show
      # rather than one waiting on a [commandfor] trigger
      def initialize(id:, title: nil, open: false)
        @id = id
        @title = title
        @open = open
      end
    end
  end
end
