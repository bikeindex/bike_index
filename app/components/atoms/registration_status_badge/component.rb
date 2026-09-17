# frozen_string_literal: true

module Atoms
  module RegistrationStatusBadge
    # A bike's registration status as a badge, with a tooltip explaining what the
    # status means. The label is Bike's own humanized status, so "with owner" reads
    # as "registered" everywhere at once.
    class Component < ApplicationComponent
      COLORS = {
        with_owner: :success,
        for_sale: :purple,
        stolen: :error,
        impounded: :warning,
        found: :warning,
        abandoned: :warning,
        unregistered: :pink
      }.freeze

      # Tables and columns that only call out the exceptional statuses pass skip_with_owner
      def self.status_humanized(bike, override_status: nil, skip_with_owner: false)
        status = override_status.presence || bike.status_humanized
        (skip_with_owner && status == "with owner") ? "" : status
      end

      # override_status: the marketplace preview, where the listing is still a draft
      def initialize(bike:, override_status: nil, skip_with_owner: false, size: :md)
        @bike = bike
        @override_status = override_status
        @skip_with_owner = skip_with_owner
        @size = size
      end

      def render? = status_humanized.present?

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
        @status_humanized ||= self.class.status_humanized(@bike, override_status: @override_status,
          skip_with_owner: @skip_with_owner)
      end

      def status_key = status_humanized.tr(" ", "_").to_sym
    end
  end
end
