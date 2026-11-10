module Organized
  class EducationCoursesController < Organized::AdminController
    before_action :ensure_access_to_education_courses!
    before_action :ensure_access_to_edit_education_courses!, except: %i[index show]
    helper_method :can_edit_education_courses?

    def index
      @draft = current_organization.education_courses.draft.first if can_edit_education_courses?
      @active = EducationCourse.active_for(current_organization)
      @previous = current_organization.education_courses.archived.order(end_at: :desc).to_a
    end

    # The faked registrant walk-through, one screen (?page=) per rule page plus the review
    # they end on. page is 1-indexed (Pagy); the preview component's index is 0-based.
    def show
      @education_course = current_organization.education_courses.find(params[:id])
      return raise_do_not_have_access! if @education_course.draft? && !can_edit_education_courses?

      screen_count = BikeServices::Register.acknowledgment_step_count(@education_course)
      @preview_pagy = Pagy::Offset.new(count: screen_count, limit: 1, page: permitted_page(max: screen_count))
    end

    # Manage the draft's pages (add / reorder / edit) and its course-wide settings
    def edit
      @education_course = find_draft
    end

    # The settings shared by every page: the FAQ link and the final acknowledgment
    def update
      @education_course = find_draft
      if @education_course.update(permitted_params)
        flash[:success] = "Education course updated"
        redirect_to edit_organization_education_course_path(organization_id: current_organization.to_param, id: @education_course.id)
      else
        flash.now[:error] = @education_course.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    # Opens the draft the org manages, cloning the live course (or the template) on first edit
    def create
      draft = EducationCourse.draft_for(current_organization)
      redirect_to edit_organization_education_course_path(organization_id: current_organization.to_param, id: draft.id)
    end

    # Throw the draft away to start over; the live course is untouched
    def destroy
      find_draft.discard_draft!
      flash[:success] = "Draft discarded"
      redirect_to organization_education_courses_path(organization_id: current_organization.to_param)
    end

    private

    def find_draft
      current_organization.education_courses.draft.find(params[:id])
    end

    def permitted_params
      params.require(:education_course).permit(:faq_url, :acknowledgment_text)
    end

    # Superusers can view regardless; org admins/members need the feature flag
    def ensure_access_to_education_courses!
      return unless ensure_current_organization!
      return true if current_organization.enabled?("education_courses") || current_user.superuser?

      raise_do_not_have_access!
    end

    def ensure_access_to_edit_education_courses!
      return true if can_edit_education_courses?

      raise_do_not_have_access!
    end

    def can_edit_education_courses?
      current_organization.enabled?("education_courses_edit") || current_user.superuser?
    end
  end
end
