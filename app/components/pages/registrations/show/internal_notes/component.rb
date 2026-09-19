# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module InternalNotes
        class Component < ApplicationComponent
          def initialize(note:, url:, current_user:, previous_notes: note&.previous_notes || [])
            @note = note
            @previous_notes = previous_notes
            @url = url
            @current_user = current_user
          end

          private

          def label_text
            safe_join([translation(".current_note"),
              tag.span(translation(".posting_as", user: @current_user.display_name), class: "tw:text-sm tw:font-normal tw:opacity-65")], " ")
          end

          def note_by(note)
            safe_join([translation(".note_by", user: note.user&.display_name),
              render(UI::Time::Component.new(time: note.updated_at))], " ")
          end
        end
      end
    end
  end
end
