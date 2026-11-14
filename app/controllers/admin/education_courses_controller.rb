module Admin
  class EducationCoursesController < Admin::BaseController
    include Binxtils::SortableTable

    before_action :find_education_course, only: %i[show preview edit]
    # Activation freezes a course, so the actions that change one only ever find a draft
    before_action :find_draft, only: %i[update destroy]

    def index
      # The course organizations' drafts are cloned from, reachable without hunting the
      # table for it. Its draft when there is one - that's what there is to do to it
      @default_course = ::EducationCourse.existing_draft_for(nil) || ::EducationCourse.active_default
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_education_courses.includes(:organization, :education_course_pages)
          .reorder(sortable_order(EducationCourse)),
        limit: @per_page,
        page: permitted_page)
    end

    # The course's pages and settings, read-only - editing it is #edit
    def show
    end

    # The faked registrant walk-through, one screen (?page=) per rule page plus the review
    # they end on. page is 1-indexed (Pagy); the preview component's index is 0-based.
    def preview
      screen_count = BikeServices::Register.acknowledgment_step_count(@education_course)
      @preview_pagy = Pagy::Offset.new(count: screen_count, limit: 1, page: permitted_page(max: screen_count))
    end

    # An activated course renders read-only - acknowledgments reference what it says
    def edit
    end

    # An activate param makes the draft live; otherwise it's the settings shared by every
    # page, the FAQ link and the final acknowledgment
    def update
      if params[:activate].present?
        make_active
      elsif @education_course.update(permitted_params)
        flash[:success] = "Education course updated"
        redirect_to EducationCoursePaths.edit(@education_course, admin: true)
      else
        flash.now[:error] = @education_course.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    # Opens the draft, cloning the live course on first edit. No organization_id is the
    # default course - friendly_find! so a typo 404s rather than opening the default's draft
    def create
      organization = ::Organization.friendly_find!(params[:organization_id]) if params[:organization_id].present?
      redirect_to EducationCoursePaths.edit(::EducationCourse.draft_for(organization), admin: true)
    end

    # Throw the draft away to start over; the live course is untouched
    def destroy
      @education_course.discard_draft!
      flash[:success] = "Draft discarded"
      redirect_to EducationCoursePaths.index(@education_course, admin: true)
    end

    helper_method :matching_education_courses, :searchable_statuses

    def searchable_statuses
      ::EducationCourse::STATUSES
    end

    protected

    def sortable_columns
      %w[created_at updated_at start_at end_at organization_id].freeze
    end

    def earliest_period_date
      Time.at(1780272000) # 2026-06-01 - education courses introduced
    end

    def matching_education_courses
      education_courses = ::EducationCourse.all
      @status = searchable_statuses.include?(params[:search_status]) ? params[:search_status] : nil
      education_courses = education_courses.for_status(@status) if @status.present?

      if params[:organization_id].present?
        education_courses = education_courses.where(organization_id: params[:organization_id])
      end

      @time_range_column = sort_column if %w[updated_at].include?(sort_column)
      @time_range_column ||= "created_at"
      education_courses.where(@time_range_column => @time_range)
    end

    def find_education_course
      @education_course = ::EducationCourse.includes(:organization, :education_course_pages)
        .find(params[:id])
    end

    def find_draft
      @education_course = ::EducationCourse.draft.find(params[:id])
    end

    # Archives the course it supersedes. Organizations ask us to do this for them -
    # their own screens only get them as far as a finished draft
    def make_active
      if @education_course.make_active!
        flash[:success] = "#{@education_course.display_name} education course is live"
        redirect_to EducationCoursePaths.course(@education_course, admin: true)
      else
        flash[:error] = "Unable to activate - every page needs a title and rules"
        redirect_to EducationCoursePaths.edit(@education_course, admin: true)
      end
    end

    def permitted_params
      params.require(:education_course).permit(:faq_url, :acknowledgment_text)
    end
  end
end
