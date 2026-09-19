# frozen_string_literal: true

module Pages
  module Admin
    module RegistrationSequence
      module Table
        class Component < ApplicationComponent
          def initialize(registration_sequences:, sort_state: ComponentStructs::SortState.new, render_sortable: false)
            @registration_sequences = registration_sequences
            @sort_state = sort_state
            @render_sortable = render_sortable
          end
        end
      end
    end
  end
end
