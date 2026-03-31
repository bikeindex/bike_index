# frozen_string_literal: true

module UI
  module Time
    class Component < ApplicationComponent
      PERMITTED_FORMATS = %i[convert_time convert_time_precise hour date_hour date].freeze

      def initialize(time: nil, format: nil, timezone_if_different: false)
        @time = time
        @format = PERMITTED_FORMATS.include?(format&.to_sym) ? format.to_sym : PERMITTED_FORMATS.first
        # dates don't have timezones - so skip the rest of the initialization
        if @time.is_a?(Date) && @format == :date
          @time = @time.beginning_of_day
        else
          @timezone = time&.zone
        end

        # Raise error in dev for invalid format
        if Rails.env.development? && format.present? && @format != format.to_sym
          raise "Unknown format '#{format}', must be one of: #{PERMITTED_FORMATS}"
        end
      end

      def call
        if convert_time_format?
          extra_class = (@format == :convert_time_precise) ? "preciseTime" : nil
          content_tag(:span, formatted_date_time, class: "localizeTime #{extra_class}")
        elsif @format == :date
          content_tag(:span, formatted_date, title: l(@time, format: :full_date_year))
        else
          content_tag(:span, formatted_date_time, title: time_title)
        end
      end

      private

      def render?
        @time.present?
      end

      def convert_time_format?
        %i[convert_time convert_time_precise].include?(@format)
      end

      def formatted_date_time
        return l(@time, format: :convert_time) if convert_time_format?

        time_str = l(@time, format: ((@time.min == 0) ? :hour : :hour_minute))
        return time_str if @format == :hour

        [
          l(@time, format: ((@time.year == ::Time.current.year) ? :date : :date_year)),
          time_str
        ].join(", ").strip
      end

      def time_title
        l(@time, format: :full_datetime)
      end

      def formatted_date
        l(@time, format: ((@time.year == ::Time.current.year) ? :full_date : :full_date_year))
      end
    end
  end
end
