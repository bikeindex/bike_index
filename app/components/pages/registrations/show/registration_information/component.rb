# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module RegistrationInformation
        class Component < ApplicationComponent
          # Registration fields shown with the owner rather than in registration information
          OWNER_ACCESS_REG_FIELDS = %w[reg_address reg_organization_affiliation reg_student_id].freeze

          class << self
            # [label, value] for each of reg_fields the organization collects
            def field_rows(bike:, organization:, reg_fields:)
              (reg_fields & organization.additional_registration_fields).map do |reg_field|
                bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field)
                [field_label(organization, reg_field, bike_attr), field_value(bike, organization, bike_attr)]
              end
            end

            private

            def field_value(bike, organization, bike_attr)
              case bike_attr
              when "organization_affiliation" then bike.organization_affiliation(organization)&.humanize
              when "student_id" then bike.student_id(organization)
              when "address" then registration_address(bike, organization)
              else bike.send(bike_attr)
              end
            end

            def field_label(organization, reg_field, bike_attr)
              custom = organization.registration_field_labels&.dig(reg_field)
              return Binxtils::InputNormalizer.sanitize(custom) if custom.present?

              bike_attr.humanize(keep_id_suffix: true)
            end

            def registration_address(bike, organization)
              address = bike.registration_address
              return if address.blank? || address == organization.default_location&.address_hash_legacy

              [address["street"], address["city"], [address["state"], address["zipcode"]].compact_blank.join(" ")]
                .compact_blank.join(", ").presence
            end
          end

          def initialize(bike:, organization:, org_role:)
            @bike = bike
            @organization = organization
            @org_role = org_role
          end

          private

          def info_row(label, value = nil, &block)
            render(UI::DefinitionList::Row::Component.new(label:, value:, render_with_no_value: true, no_value_text: "-"), &block)
          end

          def staff?
            @org_role == :staff
          end

          def organization_registered?
            return @organization_registered if defined?(@organization_registered)

            @organization_registered = @bike.organized?(@organization)
          end

          def unregistered?
            @bike.unregistered_parking_notification?
          end

          # Contact and law-enforcement data: full staff only, on their own org's bike
          def show_contact?
            staff? && organization_registered?
          end

          # Every row is feature- or registration-gated
          def registration_information?
            organization_registered? || @organization.any_enabled?(%w[credibility_badges bike_stickers])
          end

          def credibility_scorer
            @credibility_scorer ||= @bike.credibility_scorer
          end

          def credibility_score
            @credibility_score ||= credibility_scorer.score
          end

          # Matches the credibility_scorer_color used on bikes/show
          def credibility_color
            return "#dc3545" if credibility_score < 31
            return "#ffc107" if credibility_score < 70

            "#28a745"
          end

          def credibility_badges
            @credibility_badges ||= CredibilityScorer.permitted_badges_hash(credibility_scorer.badges)
          end

          def bike_stickers
            @bike_stickers ||= @bike.bike_stickers.reorder(claimed_at: :desc)
          end

          def sticker_link(bike_sticker)
            url = if bike_sticker.organization_id == @organization.id
              edit_organization_sticker_path(id: bike_sticker.code, organization_id: @organization.to_param)
            end

            render(Atoms::Sticker::Component.new(bike_sticker:, url:))
          end

          def model_audit
            return @model_audit if defined?(@model_audit)

            @model_audit = @bike.model_audit
          end

          def organization_model_audit
            return @organization_model_audit if defined?(@organization_model_audit)

            @organization_model_audit = model_audit &&
              OrganizationModelAudit.find_by(organization_id: @organization.id, model_audit_id: @bike.model_audit_id)
          end

          # Only e-vehicles go through a registration sequence
          def show_registration_sequence?
            @bike.motorized? && @organization.enabled?("registration_sequences")
          end

          def acknowledgment
            return @acknowledgment if defined?(@acknowledgment)

            @acknowledgment = RegistrationSequenceAcknowledgment.find_for(bike: @bike, organization: @organization)
          end

          # Blank ones dropped. Sticker and phone are shown elsewhere
          def registration_field_rows
            reg_fields = @organization.additional_registration_fields - %w[reg_bike_sticker reg_phone] - OWNER_ACCESS_REG_FIELDS
            self.class.field_rows(bike: @bike, organization: @organization, reg_fields:)
              .reject { |_label, value| value.blank? }
          end
        end
      end
    end
  end
end
