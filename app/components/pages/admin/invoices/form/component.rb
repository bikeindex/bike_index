# frozen_string_literal: true

module Pages
  module Admin
    module Invoices
      module Form
        # The invoice form, on both new and edit. The feature checkboxes and the running totals
        # are driven by the vendored admin bundle, which finds them by id.
        class Component < ApplicationComponent
          def initialize(organization:, invoice:, organization_features:, display_dev_info: false)
            @organization = organization
            @invoice = invoice
            @organization_features = organization_features
            @display_dev_info = display_dev_info
          end

          private

          # Memoized - read once per checkbox otherwise, and it's a query each time
          def selected_feature_ids = @selected_feature_ids ||= @invoice.organization_feature_ids

          # Named individually rather than as an array, so the ids ride in a hidden field the
          # controller rewrites - see admin--invoice-form
          def feature_checkbox(organization_feature)
            check_box_tag "organization_feature_ids_#{organization_feature.id}", organization_feature.id,
              selected_feature_ids.include?(organization_feature.id),
              data: {"admin--invoice-form-target": "feature", action: "change->admin--invoice-form#recalculate",
                     amount: organization_feature.amount, id: organization_feature.id,
                     recurring: !organization_feature.one_time?}
          end

          def child_slugs_label
            safe_join(["Features passed on to children",
              tag.small("If this is for a parent organization, choose which features from this invoice " \
                "should apply to the child organizations", class: "em")], " ")
          end

          def show_feature_slugs?(organization_feature)
            @display_dev_info && organization_feature.feature_slugs_string.present?
          end

          # Passed to the fields rather than assigned onto the invoice - rendering it
          # shouldn't write to it
          def start_at
            Binxtils::TimeParser.round(@invoice.subscription_start_at || Time.current.beginning_of_day, "seconds")
          end

          def end_at
            Binxtils::TimeParser.round(@invoice.subscription_end_at || Time.current + 1.year, "seconds")
          end
        end
      end
    end
  end
end
