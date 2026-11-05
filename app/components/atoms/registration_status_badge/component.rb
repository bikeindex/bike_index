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

      # Forced, because a card's tw:dark:border-gray-700 sorts after them and sets every side
      BORDER_CLASSES = {
        success: "tw:border-l-green-600!",
        purple: "tw:border-l-purple-500!",
        error: "tw:border-l-red-600!",
        warning: "tw:border-l-amber-500!",
        pink: "tw:border-l-pink-400!"
      }.freeze

      # Tables and columns that only call out the exceptional statuses pass skip_with_owner
      def self.status_humanized(bike, override_status: nil, skip_with_owner: false)
        status = override_status.presence || bike.status_humanized
        (skip_with_owner && status == "with owner") ? "" : status
      end

      def self.status_key(status_humanized) = status_humanized.tr(" ", "_").to_sym

      def self.color(bike) = COLORS[status_key(status_humanized(bike))]

      def self.border_class(bike) = BORDER_CLASSES[color(bike)]

      # override_status: the marketplace preview, where the listing is still a draft
      # time: when the status began, rendered after the label
      def initialize(bike:, override_status: nil, skip_with_owner: false, size: :md, time: nil)
        @bike = bike
        @time = time
        @override_status = override_status
        @skip_with_owner = skip_with_owner
        @size = size
      end

      def render? = status_humanized.present?

      def call
        render(UI::Badge::Component.new(text: label, title: translation(".#{status_key}"), color: COLORS[status_key], size: @size)) do
          tag.span(safe_join([tag.span(label, class: "tw:whitespace-nowrap tw:uppercase"), *time_suffix]))
        end
      end

      private

      def label = @label ||= Bike.status_humanized_translated(status_humanized).titleize

      # Plain spaces, so they collapse into the space the localizer puts before a time of day.
      # The badge can break here rather than overflow a narrow card
      def time_suffix
        return [] if @time.blank?
        [" · ", tag.span(render(UI::Time::Component.new(time: @time)), class: "tw:whitespace-nowrap")]
      end

      def status_humanized
        @status_humanized ||= self.class.status_humanized(@bike, override_status: @override_status,
          skip_with_owner: @skip_with_owner)
      end

      def status_key = self.class.status_key(status_humanized)
    end
  end
end
