# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ContactImpound
        # Messaging whoever holds an impounded or found vehicle, for the organizations
        # trusted to do it without opening a claim. Mirrors the contact-owner card, which
        # covers the stolen registrations this one doesn't.
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, owner: false)
            @bike = bike
            @current_user = current_user
            @owner = owner
          end

          # Never to the owner, and gated on the same predicate the submit is, so a
          # rendered form is one that will be accepted. Stolen registrations are the
          # contact-owner card's, and never carry an impound record
          def render?
            return false if @owner || impound_record.blank?

            @bike.contact_owner?(@current_user)
          end

          private

          def impound_record
            @impound_record ||= @bike.current_impound_record
          end

          def heading
            translation(@bike.status_found? ? ".contact_the_finder" : ".contact_the_owner")
          end

          def stolen_notification
            @stolen_notification ||= StolenNotification.new(bike: @bike)
          end

          # Whoever registered the find is its owner of record, so this is the same
          # visibility question the contact-owner card asks
          def owner_phone
            return @owner_phone if defined?(@owner_phone)

            @owner_phone = @bike.phone if @bike.phoneable_by?(@current_user)
          end
        end
      end
    end
  end
end
