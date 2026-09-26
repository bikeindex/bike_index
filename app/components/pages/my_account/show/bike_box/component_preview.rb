# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeBox
        class ComponentPreview < ApplicationComponentPreview
          # @!group Registrations
          def stolen
            render_box(bike(id: 41, status: :status_stolen, occurred_at: 3.days.ago,
              current_stolen_record: ::StolenRecord.new(city: "Chicago")))
          end

          # An impound record with no organization is someone finding it, not impounding it
          def found
            render_box(bike(id: 42, status: :status_impounded, occurred_at: 2.weeks.ago,
              current_impound_record: ::ImpoundRecord.new))
          end

          def with_owner
            render_box(bike(id: 43))
          end

          def with_owner_with_photo
            render_box(bike(id: 44, thumb_path: Pages::SearchResults::BikeBox::ComponentPreview.vehicles.first.thumb_path))
          end

          # The register flow creates the bike before its organization's safety rules are agreed to
          def unfinished_registration_alert
            with_alert = bike(id: 45)
            b_param = ::BParam.new(id_token: "preview-token", origin: "register_flow", created_at: Time.current,
              creator: preview_user, created_bike_id: with_alert.id,
              params: {acknowledgment_pending: true,
                       bike: {manufacturer_id: 1, cycle_type: "bike", owner_email: preview_user.email}})
            render_box(with_alert, user_alerts: [::UserAlert.new(id: 1, kind: "unfinished_registration",
              bike_id: with_alert.id, alertable: b_param)])
          end

          def unassigned_bike_org_alert
            with_alert = bike(id: 46)
            organization = lookbook_organization || ::Organization.new(name: "Brakebills University", short_name: "Brakebills")
            render_box(with_alert, user_alerts: [::UserAlert.new(id: 2, kind: "unassigned_bike_org",
              bike_id: with_alert.id, organization:)])
          end
          # @!endgroup

          private

          def render_box(bike, user_alerts: [])
            render_with_template(template: "pages/my_account/show/bike_box/component_preview/bike_box",
              locals: {bike:, current_user: preview_user, user_alerts:})
          end

          def preview_user
            @preview_user ||= ::User.new(email: "preview@bikeindex.org")
          end

          def bike(**attrs)
            ::Bike.new(serial_number: "PREVIEW#{attrs[:id]}", mnfg_name: "Surly", frame_model: "Cross Check",
              year: 2018, primary_frame_color: ::Color.find_by(name: "Purple"), created_at: 2.months.ago,
              updated_at: 1.week.ago, **attrs)
          end
        end
      end
    end
  end
end
