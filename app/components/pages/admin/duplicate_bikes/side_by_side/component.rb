# frozen_string_literal: true

module Pages
  module Admin
    module DuplicateBikes
      module SideBySide
        # A small group's records in columns, every compared value in a row, rows that differ highlighted.
        # link_params: the page's own params
        class Component < ApplicationComponent
          def initialize(review:, link_params:)
            @review = review
            @link_params = link_params
          end

          private

          # [label, values to compare, markup to show] - a row with no values to compare is never highlighted
          def rows
            bikes = @review.bikes
            initials = bikes.map { @review.initial_ownership(it) }
            currents = bikes.map(&:current_ownership)
            [
              ["Registered", nil, bikes.map { render(UI::Time::Component.new(time: it.created_at)) }],
              *BikeDuplicatesServices::Review::FIELDS.keys.map do |field|
                values = bikes.map { @review.field_value(it, field) }
                [field, values, field.end_with?("serial") ? values.map { serial(it) } : values]
              end,
              ["Initial source", bikes.map { @review.source(it) }],
              ["Initial organization", bikes.map { @review.organization(it)&.name }],
              ["Initial contact email", initials.map { @review.contact_email(it) }],
              ["Initial account", initials.map { it&.user_id }, initials.map { account_link(it) }],
              ["Initial account email", initials.map { @review.account_email(it&.user_id) }],
              ["Initial claim", initials.map { @review.claim_status(it) },
                initials.map { safe_join([@review.claim_status(it), " ", render(UI::Time::Component.new(time: it&.claimed_at))]) }],
              ["Initial vs reference", nil, bikes.map { [@review.account_match(it, initial: true), @review.email_evidence(it, initial: true)].join(" · ") }],
              ["Current contact email", currents.map { @review.contact_email(it) }],
              ["Current account", currents.map { it&.user_id }, currents.map { account_link(it) }],
              ["Current account email", currents.map { @review.account_email(it&.user_id) }],
              ["Current claim", currents.map { @review.claim_status(it) }],
              ["Current vs reference", nil, bikes.map { [@review.account_match(it), @review.email_evidence(it)].join(" · ") }],
              ["Transfers", bikes.map { it.ownerships.count(&:previous_ownership_id) }],
              ["Stolen/history records", bikes.map { @review.stolen_count(it) }],
              ["Organization links", bikes.map { it.bike_organizations.size }],
              ["Stickers", bikes.map { it.bike_stickers.size }],
              ["Photos", bikes.map { it.public_images.size }],
              ["Marketplace listings", bikes.map { it.marketplace_listings.size }]
            ]
          end

          def differs?(values) = values && values.map(&:to_s).uniq.size > 1

          def cell(value) = value.is_a?(Integer) ? number_display(value) : (value.presence || "—")

          def serial(value) = render(Atoms::Serial::Component.new(serial: value))

          def account_link(ownership)
            ownership&.user_id && link_to("##{ownership.user_id}", admin_user_path(ownership.user_id), class: "twlink")
          end
        end
      end
    end
  end
end
