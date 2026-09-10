# frozen_string_literal: true

module Pages
  module Bikes
    module StolenChecklist
      # What getting a stolen bike back takes, with what's already done ticked off.
      # Rendered on the theft details and publicize editors, at the end of the register
      # flow, and in the stolen bike alert email.
      class Component < ApplicationComponent
        # The email loads email.css rather than tailwind, so the legacy class names stay on
        # as its styling hooks (revised/emails/email_stolen_checklist) - on the web they're
        # inert, and the tw: classes beside them are what render it
        # pl-9 rather than pl-8: the circle ends at 28px, so this leaves a gap beside it
        ITEM_CLASSES = "tw:relative tw:mt-2 tw:block tw:pl-9 tw:leading-normal"
        # size-6 over a 2px border leaves a 20px line box; nudged down so the tick sits on
        # the same baseline as the item's first line rather than 2px above it
        BOX_CLASSES = "tw:absolute tw:top-0.5 tw:left-1 tw:block tw:min-h-6 tw:min-w-6 " \
          "tw:rounded-full tw:border-2 tw:border-[#919197] tw:bg-white tw:text-center " \
          "tw:leading-5 tw:text-[#919197]"
        # The sub-list's marker is a dash rather than a circle
        DASH_CLASSES = "tw:absolute tw:top-3 tw:left-1 tw:block tw:min-h-[0.2em] tw:min-w-6 " \
          "tw:border-2 tw:border-[#919197] tw:bg-[#919197]"

        def initialize(bike:, stolen_record:)
          @bike = bike
          @stolen_record = stolen_record
        end

        def render? = @stolen_record&.display_checklist?

        private

        # The copy stays under bikes.stolen_checklist rather than moving to this component -
        # it's translated into four other locales there, which a rename would orphan
        def translation(key, **kwargs)
          super(key, scope: [:bikes, :stolen_checklist], **kwargs)
        end

        def item_classes(completed)
          return ITEM_CLASSES unless completed

          "#{ITEM_CLASSES} completed-item tw:opacity-75"
        end

        def text_classes(completed)
          completed ? "checklist-text tw:line-through" : "checklist-text"
        end

        # ✓ for a done item, an empty circle for one still to do
        def box(completed)
          tag.span(completed ? "✓" : "", class: "checklist-checkbox #{BOX_CLASSES}")
        end

        def dash = tag.span("", class: "checklist-uncheckbox #{DASH_CLASSES}")

        def serial_unknown? = @bike.serial_unknown?

        def police_report? = @stolen_record.police_report_number.present?

        def street? = @stolen_record.street.present?

        def images? = @bike.public_images.any?

        # The police services need a serial to search on, so a report without one isn't sent
        def submitted_to_police_services? = police_report? && !serial_unknown?

        def netherlands? = @stolen_record.country == Country.netherlands

        def approved? = @stolen_record.approved

        def theft_alert? = @stolen_record.theft_alerts.any?

        def organization_stolen_message
          @stolen_record.organization_stolen_message if
            @stolen_record.organization_stolen_message&.shown_to?(@stolen_record)
        end

        def edit_path(template, anchor: nil)
          edit_bike_url(id: @bike.to_param, edit_template: template, anchor:)
        end
      end
    end
  end
end
