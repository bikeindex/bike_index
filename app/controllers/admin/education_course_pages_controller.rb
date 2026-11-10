module Admin
  class EducationCoursePagesController < Admin::BaseController
    before_action :find_education_course, only: %i[new create]
    before_action :find_page, only: %i[edit update destroy]

    # A blank page to fill in; it's only persisted once it has a title and rules
    def new
      @page = @education_course.education_course_pages.new
      render :edit
    end

    def create
      @page = @education_course.education_course_pages.new(permitted_parameters)
      if @page.save
        flash[:success] = "Page added"
        redirect_to EducationCoursePaths.edit(@education_course, admin: true)
      else
        flash.now[:error] = "Unable to add: #{@page.errors.full_messages.to_sentence}"
        render :edit, status: :unprocessable_entity
      end
    end

    def edit
    end

    # A position reorders the page (drag-and-drop on the edit page); otherwise it's a field edit
    def update
      if params[:position].present?
        @education_course.reorder_page!(@page, params[:position].to_i)
        head :ok
      elsif @page.update(permitted_parameters)
        flash[:success] = "Page updated"
        # Back to this page so the refreshed preview is right there
        redirect_to EducationCoursePaths.edit_page(@page, admin: true)
      else
        flash[:error] = "Unable to update: #{@page.errors.full_messages.to_sentence}"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @page.destroy
      flash[:success] = "Page removed"
      redirect_to EducationCoursePaths.edit(@education_course, admin: true)
    end

    private

    # Activation freezes a course and its pages, so only drafts are edited
    def find_education_course
      @education_course = ::EducationCourse.draft.find(params[:education_course_id])
    end

    def find_page
      @page = ::EducationCoursePage.where(education_course: ::EducationCourse.draft)
        .find(params[:id])
      @education_course = @page.education_course
    end

    def permitted_parameters
      params.require(:education_course_page).permit(:title, :heading, :subtitle, :image, :body, :organization_specific)
    end
  end
end
