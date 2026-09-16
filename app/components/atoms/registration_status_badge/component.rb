# frozen_string_literal: true

module Atoms
  module RegistrationStatusBadge
    # A bike's registration status as a badge, with a tooltip explaining what the
    # status means. The label is Bike's own humanized status, so "with owner"
    # reads as "registered" here and everywhere else at once.
    class Component < ApplicationComponent
      COLORS = {
        with_owner: :success,
        for_sale: :purple,
        stolen: :error,
        impounded: :warning,
        found: :warning,
        abandoned: :warning,
        unregistered: :warning
      }.freeze

      # override_to_for_sale: the marketplace preview, where the listing is still a draft
      def initialize(bike:, override_to_for_sale: false, skip_with_owner: false, size: :md)
        @bike = bike
        @override_to_for_sale = override_to_for_sale
        @skip_with_owner = skip_with_owner
        @size = size
      end

      # Tables and titles that only call out the exceptional statuses pass skip_with_owner
      def render?
        !(@skip_with_owner && status_key == :with_owner)
      end

      def call
        render(UI::Badge::Component.new(
          text: Bike.status_humanized_translated(status_humanized).titleize,
          title: translation(".#{status_key}"),
          color: COLORS[status_key],
          size: @size,
          indicator: true
        ))
      end

      private

      def status_humanized
        @status_humanized ||= if @override_to_for_sale && @bike.status_with_owner?
          "for sale"
        else
          @bike.status_humanized
        end
      end

      def status_key
        @status_key ||= status_humanized.tr(" ", "_").to_sym
      end
    end
  end
end
