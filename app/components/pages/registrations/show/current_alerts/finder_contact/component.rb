# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module FinderContact
          # How a paid organization reaches whoever registered a found vehicle. Separate
          # from the claim card beside it, which asks the opposite question of the public
          class Component < ApplicationComponent
            def initialize(bike:, organization: nil)
              @bike = bike
              @organization = organization
            end

            def render?
              BikeServices::Displayer.display_found_contact?(@bike, @organization)
            end

            private

            # Whoever registered the find is the owner of record until it's claimed
            def finder_name
              @bike.owner_name
            end

            def finder_email
              @bike.owner_email
            end

            # Bike#phone re-queries ownerships on every call, memoized or not
            def finder_phone
              return @finder_phone if defined?(@finder_phone)

              @finder_phone = @bike.phone
            end
          end
        end
      end
    end
  end
end
