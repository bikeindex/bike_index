# frozen_string_literal: true

# The sequence editor renders for an organization and for admin, which edits any
# sequence. Only the routes differ, so the components ask here.
module EducationCoursePaths
  extend Functionable

  # Admin lists an organization's sequences on a tab of its organization page
  def index(education_course, admin: false)
    return routes.organization_education_courses_path(organization_id: organization_param(education_course)) unless admin
    return routes.admin_education_courses_path if education_course.template?

    routes.admin_organization_path(organization_param(education_course), active_tab: "education_courses")
  end

  # Admin's read-only screen, and the PATCH target for both. An organization has no
  # read-only screen - its member path is the preview
  def sequence(education_course, page: nil, admin: false)
    return routes.admin_education_course_path(education_course, page:) if admin

    routes.organization_education_course_path(organization_id: organization_param(education_course),
      id: education_course.id, page:)
  end

  # The registrant walk-through
  def preview(education_course, page: nil, admin: false)
    return routes.preview_admin_education_course_path(education_course, page:) if admin

    sequence(education_course, page:)
  end

  # Making a draft live is admin's alone - an organization asks us to do it. It PATCHes the
  # sequence like any other edit, with the param saying which edit
  def activate(education_course)
    routes.admin_education_course_path(education_course, activate: true)
  end

  # POSTs open the owner's draft, cloning one if there isn't one. A blank organization
  # is the template
  def create_draft(organization_id) = routes.admin_education_courses_path(organization_id:)

  def edit(education_course, admin: false)
    return routes.edit_admin_education_course_path(education_course) if admin

    routes.edit_organization_education_course_path(organization_id: organization_param(education_course),
      id: education_course.id)
  end

  def new_page(education_course, admin: false)
    return routes.new_admin_education_course_page_path(education_course_id: education_course.id) if admin

    routes.new_organization_education_course_page_path(organization_id: organization_param(education_course),
      education_course_id: education_course.id)
  end

  # Where a new page is POSTed
  def pages(education_course, admin: false)
    return routes.admin_education_course_pages_path(education_course_id: education_course.id) if admin

    routes.organization_education_course_pages_path(organization_id: organization_param(education_course),
      education_course_id: education_course.id)
  end

  # Updating, reordering and deleting a page
  def page(education_course_page, admin: false)
    return routes.admin_education_course_page_path(education_course_page) if admin

    routes.organization_education_course_page_path(
      organization_id: organization_param(education_course_page.education_course),
      id: education_course_page.id
    )
  end

  def edit_page(education_course_page, admin: false)
    return routes.edit_admin_education_course_page_path(education_course_page) if admin

    routes.edit_organization_education_course_page_path(
      organization_id: organization_param(education_course_page.education_course),
      id: education_course_page.id
    )
  end

  # Leaving the preview. An organization has only the editor, and a frozen sequence
  # hasn't got one
  def preview_exit(education_course, admin: false)
    return sequence(education_course, admin: true) if admin

    education_course.activated? ? index(education_course) : edit(education_course)
  end

  #
  # private below here
  #

  def organization_param(education_course) = education_course.organization.to_param

  def routes = Rails.application.routes.url_helpers

  conceal :organization_param, :routes
end
