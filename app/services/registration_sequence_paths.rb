# frozen_string_literal: true

# The sequence editor renders for an organization and for admin, which edits any
# sequence. Only the routes differ, so the components ask here.
module RegistrationSequencePaths
  extend Functionable

  def index(registration_sequence, admin: false)
    return routes.admin_registration_sequences_path if admin

    routes.organization_registration_sequences_path(organization_id: organization_param(registration_sequence))
  end

  # Admin's read-only screen, and the PATCH target for both. An organization has no
  # read-only screen - its member path is the preview
  def sequence(registration_sequence, page: nil, admin: false)
    return routes.admin_registration_sequence_path(registration_sequence, page:) if admin

    routes.organization_registration_sequence_path(organization_id: organization_param(registration_sequence),
      id: registration_sequence.id, page:)
  end

  # The registrant walk-through
  def preview(registration_sequence, page: nil, admin: false)
    return routes.preview_admin_registration_sequence_path(registration_sequence, page:) if admin

    sequence(registration_sequence, page:)
  end

  # Making a draft live is admin's alone - an organization asks us to do it. It PATCHes the
  # sequence like any other edit, with the param saying which edit
  def activate(registration_sequence)
    routes.admin_registration_sequence_path(registration_sequence, activate: true)
  end

  # POSTs open the owner's draft, cloning one if there isn't one. A blank organization
  # is the template
  def create_draft(organization_id) = routes.admin_registration_sequences_path(organization_id:)

  def edit(registration_sequence, admin: false)
    return routes.edit_admin_registration_sequence_path(registration_sequence) if admin

    routes.edit_organization_registration_sequence_path(organization_id: organization_param(registration_sequence),
      id: registration_sequence.id)
  end

  def new_page(registration_sequence, admin: false)
    return routes.new_admin_registration_sequence_page_path(registration_sequence_id: registration_sequence.id) if admin

    routes.new_organization_registration_sequence_page_path(organization_id: organization_param(registration_sequence),
      registration_sequence_id: registration_sequence.id)
  end

  # Where a new page is POSTed
  def pages(registration_sequence, admin: false)
    return routes.admin_registration_sequence_pages_path(registration_sequence_id: registration_sequence.id) if admin

    routes.organization_registration_sequence_pages_path(organization_id: organization_param(registration_sequence),
      registration_sequence_id: registration_sequence.id)
  end

  # Updating, reordering and deleting a page
  def page(registration_sequence_page, admin: false)
    return routes.admin_registration_sequence_page_path(registration_sequence_page) if admin

    routes.organization_registration_sequence_page_path(
      organization_id: organization_param(registration_sequence_page.registration_sequence),
      id: registration_sequence_page.id
    )
  end

  def edit_page(registration_sequence_page, admin: false)
    return routes.edit_admin_registration_sequence_page_path(registration_sequence_page) if admin

    routes.edit_organization_registration_sequence_page_path(
      organization_id: organization_param(registration_sequence_page.registration_sequence),
      id: registration_sequence_page.id
    )
  end

  # Leaving the preview. An organization has only the editor, and a frozen sequence
  # hasn't got one
  def preview_exit(registration_sequence, admin: false)
    return sequence(registration_sequence, admin: true) if admin

    registration_sequence.activated? ? index(registration_sequence) : edit(registration_sequence)
  end

  #
  # private below here
  #

  def organization_param(registration_sequence) = registration_sequence.organization.to_param

  def routes = Rails.application.routes.url_helpers

  conceal :organization_param, :routes
end
