# frozen_string_literal: true

module Admin
  class EducationCourseAcknowledgmentsController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_education_course_acknowledgments.preload(:bike, education_course: :organization, user: %i[membership_active email_bans_active])
          .reorder(sortable_order(EducationCourseAcknowledgment)),
        limit: @per_page,
        page: permitted_page)
    end

    helper_method :matching_education_course_acknowledgments, :searchable_statuses

    def searchable_statuses
      %w[pending acknowledged].freeze
    end

    private

    def sortable_columns
      %w[created_at acknowledged_at education_course_id bike_id user_id owner_email].freeze
    end

    def earliest_period_date
      Time.at(1780272000) # 2026-06-01 - education courses introduced
    end

    def matching_education_course_acknowledgments
      acknowledgments = EducationCourseAcknowledgment.all
      @status = searchable_statuses.include?(params[:search_status]) ? params[:search_status] : nil
      acknowledgments = case @status
      when "pending" then acknowledgments.pending
      when "acknowledged" then acknowledgments.acknowledged
      else acknowledgments
      end

      if params[:organization_id].present?
        acknowledgments = acknowledgments.for_organization(current_organization)
      end

      if params[:search_education_course_id].present?
        acknowledgments = acknowledgments.where(education_course_id: params[:search_education_course_id])
      end

      if params[:user_id].present?
        acknowledgments = acknowledgments.where(user_id: user_subject&.id || params[:user_id])
      end

      if params[:search_bike_id].present?
        acknowledgments = acknowledgments.where(bike_id: params[:search_bike_id])
      end

      # Not acknowledged_at, even sorted by it: a period on that drops every pending record
      acknowledgments.where(created_at: @time_range)
    end
  end
end
