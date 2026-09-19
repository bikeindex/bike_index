# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module InternalNotes
        # The org's note on a registration, newest first with the notes it replaced below
        class Component < ApplicationComponent
          def initialize(notes:, url:, current_user:)
            @notes = notes
            @url = url
            @current_user = current_user
          end
        end
      end
    end
  end
end
