# frozen_string_literal: true

module UI
  module Forms
    module RequiredMarker
      class Component < ApplicationComponent
        def call = tag.span("*", class: "tw:text-red-600", title: translation(".required"))
      end
    end
  end
end
