# frozen_string_literal: true

module Admin
  module InvoiceForm
    # The invoice form, on both new and edit. The feature checkboxes and the running totals
    # are driven by the vendored admin bundle, which finds them by id.
    class Component < ApplicationComponent
      def initialize(organization:, invoice:, organization_features:)
        @organization = organization
        @invoice = invoice
        @organization_features = organization_features
      end

      private

      # Memoized - read once per checkbox otherwise, and it's a query each time
      def selected_feature_ids = @selected_feature_ids ||= @invoice.organization_feature_ids

      def feature_checkbox(organization_feature)
        check_box_tag "organization_feature_ids_#{organization_feature.id}", organization_feature.id,
          selected_feature_ids.include?(organization_feature.id),
          :class => organization_feature.one_time? ? "oneTime" : "recurring",
          "data-amount" => organization_feature.amount, "data-id" => organization_feature.id
      end

      def child_slugs_label
        safe_join(["Features passed on to children",
          tag.small("If this is for a parent organization, choose which features from this invoice " \
            "should apply to the child organizations", class: "em")], " ")
      end

      def show_feature_slugs?(organization_feature)
        helpers.display_dev_info? && organization_feature.feature_slugs_string.present?
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
