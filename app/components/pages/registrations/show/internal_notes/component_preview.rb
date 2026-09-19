# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module InternalNotes
        # In-memory notes, so nothing is written to the database
        class ComponentPreview < ApplicationComponentPreview
          def no_notes
            render_notes([])
          end

          def single_note
            render_notes([note("Owner picked it up from the rack by the library.", "Alice Staff", 2.hours.ago)])
          end

          # Each post replaces the note, and paper_trail keeps the ones before it
          def thread_with_previous_notes
            render_notes([
              note("Owner confirmed the new lock — clear to release.", "Alice Staff", 20.minutes.ago),
              note("Called the owner, left a voicemail.", "Bob Member", 1.day.ago),
              note("Found locked to the handrail outside Hall B.", "Alice Staff", 3.days.ago)
            ])
          end

          def author_deleted
            render_notes([::BikeOrganizationNote.new(body: "Written by someone who has since left.", updated_at: 1.week.ago)])
          end

          private

          def render_notes(notes)
            render(Component.new(notes:, url: "#", current_user: ::User.new(name: "Preview User")))
          end

          def note(body, user_name, updated_at)
            ::BikeOrganizationNote.new(body:, updated_at:, user: ::User.new(name: user_name))
          end
        end
      end
    end
  end
end
