# frozen_string_literal: true

module Admin::ChartOrganizationStatuses
  class Component < ApplicationComponent
    include GraphingHelper

    COLORS = %w[#FBCA04 #0E8A16 #006B75 #1D76DB #0052CC #B60205 #D93F0B #5319E7 #D4C5F9 #2C3E50 #F9D0C4 #C2E0C6 #C5DEF5 #7DCABB].freeze

    def initialize(matching_organization_statuses:, matching_organization_statuses_untimed:, time_range:, pos_kind:, ended:, current:)
      @matching_organization_statuses = matching_organization_statuses
      @matching_organization_statuses_untimed = matching_organization_statuses_untimed
      @time_range = time_range
      @pos_kind = pos_kind
      @ended = ended
      @current = current
    end

    private

    def show_with_pos_counts?
      %w[not_no_pos with_pos].include?(@pos_kind)
    end

    def pos_kinds_start_counts
      @pos_kinds_start_counts ||= build_pos_kind_data(:start_at).first
    end

    def start_colors
      @start_colors ||= build_pos_kind_data(:start_at).last
    end

    def pos_kinds_end_counts
      @pos_kinds_end_counts ||= build_pos_kind_data(:end_at).first
    end

    def end_colors
      @end_colors ||= build_pos_kind_data(:end_at).last
    end

    def build_pos_kind_data(column)
      counts = []
      colors = []
      Organization.pos_kinds.each_with_index do |k, i|
        scoped = @matching_organization_statuses.where(pos_kind: k)
        next unless scoped.where(column => @time_range).limit(1).present?

        counts << {name: k.humanize, data: time_range_counts(collection: scoped, column:)}
        colors << COLORS[i]
      end
      [counts, colors]
    end

    def start_count
      scope = show_with_pos_counts? ? @matching_organization_statuses_untimed.with_pos : @matching_organization_statuses_untimed
      scope.at_time(@time_range.first).count
    end

    def end_count
      scope = show_with_pos_counts? ? @matching_organization_statuses_untimed.with_pos : @matching_organization_statuses_untimed
      scope.at_time(@time_range.last).count
    end
  end
end
