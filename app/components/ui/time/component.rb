# frozen_string_literal: true

module UI
  module Time
    class Component < ApplicationComponent
      PERMITTED_FORMATS = %i[localize_time localize_time_precise].freeze

      def initialize(time: nil, format: nil)
        @time = time
        @format = PERMITTED_FORMATS.include?(format&.to_sym) ? format.to_sym : PERMITTED_FORMATS.first
        @timezone = time&.zone

        # Raise error in dev for invalid format
        if Rails.env.development? && format.present? && @format != format.to_sym
          raise "Unknown format '#{format}', must be one of: #{PERMITTED_FORMATS}"
        end
      end

      def call
        extra_class = (@format == :localize_time_precise) ? "preciseTime" : nil
        content_tag(:span, l(@time, format: :localize_time), class: "localizeTime #{extra_class}")
      end

      private

      def render?
        @time.present?
      end
    end
  end
end
