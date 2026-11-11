module Organized
  class EducationCoursePagesController < Organized::AdminController
    before_action :ensure_access_to_edit_education_courses!
    before_action :find_draft, only: %i[new create]
    before_action :find_page, only: %i[edit update destroy]

    # A blank page to fill in; it's only persisted once it has a title and rules
    def new
      @page = @draft.education_course_pages.new
      render :edit
    end

    def create
      @page = @draft.education_course_pages.new(permitted_parameters)
      if @page.save
        flash[:success] = "Page added"
        redirect_to EducationCoursePaths.edit(@draft)
      else
        flash.now[:error] = "Unable to add: #{@page.errors.full_messages.to_sentence}"
        render :edit, status: :unprocessable_entity
      end
    end

    def edit
    end

    # A position reorders the page (drag-and-drop on the show page); otherwise it's a field edit
    def update
      if params[:position].present?
        @draft.reorder_page!(@page, params[:position].to_i)
        head :ok
      elsif @page.update(permitted_parameters)
        flash[:success] = "Page updated"
        # Back to this page so the refreshed preview is right there
        redirect_to EducationCoursePaths.edit_page(@page)
      else
        flash[:error] = "Unable to update: #{@page.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    def destroy
      @page.destroy
      flash[:success] = "Page removed"
      redirect_to EducationCoursePaths.edit(@draft)
    end

    private

    # Every action here changes the draft, so the edit feature gates the whole controller
    def ensure_access_to_edit_education_courses!
      return unless ensure_current_organization!
      return true if current_organization.enabled?("education_courses_edit") || current_user.superuser?

      raise_do_not_have_access!
    end

    def find_draft
      @draft = current_organization.education_courses.draft.find(params[:education_course_id])
    end

    # Pages are only editable on the org's draft course
    def find_page
      @page = EducationCoursePage
        .where(education_course: current_organization.education_courses.draft)
        .find(params[:id])
      @draft = @page.education_course
    end

    def permitted_parameters
      params.require(:education_course_page).permit(:title, :heading, :subtitle, :image, :body, :organization_specific)
    end
  end
end
