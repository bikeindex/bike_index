# frozen_string_literal: true

# The sequence editor renders in two places - an organization managing its own sequence,
# and admin, which edits any of them (including the template org drafts are cloned from).
# Only the routes differ, so the components take one of these instead of building paths.
class RegistrationSequencePaths
  include Rails.application.routes.url_helpers

  def initialize(admin: false)
    @admin = admin
  end

  def index(registration_sequence)
    return admin_registration_sequences_path if @admin

    organization_registration_sequences_path(organization_id: organization_param(registration_sequence))
  end

  # The preview - and, as a PATCH, where the sequence-wide settings are saved
  def sequence(registration_sequence, page: nil)
    return admin_registration_sequence_path(registration_sequence, page:) if @admin

    organization_registration_sequence_path(organization_id: organization_param(registration_sequence),
      id: registration_sequence.id, page:)
  end

  def edit(registration_sequence)
    return edit_admin_registration_sequence_path(registration_sequence) if @admin

    edit_organization_registration_sequence_path(organization_id: organization_param(registration_sequence),
      id: registration_sequence.id)
  end

  def new_page(registration_sequence)
    return new_admin_registration_sequence_page_path(registration_sequence_id: registration_sequence.id) if @admin

    new_organization_registration_sequence_page_path(organization_id: organization_param(registration_sequence),
      registration_sequence_id: registration_sequence.id)
  end

  # Where a new page is POSTed
  def pages(registration_sequence)
    return admin_registration_sequence_pages_path(registration_sequence_id: registration_sequence.id) if @admin

    organization_registration_sequence_pages_path(organization_id: organization_param(registration_sequence),
      registration_sequence_id: registration_sequence.id)
  end

  # Updating, reordering and deleting a page
  def page(registration_sequence_page)
    return admin_registration_sequence_page_path(registration_sequence_page) if @admin

    organization_registration_sequence_page_path(
      organization_id: organization_param(registration_sequence_page.registration_sequence),
      id: registration_sequence_page.id
    )
  end

  def edit_page(registration_sequence_page)
    return edit_admin_registration_sequence_page_path(registration_sequence_page) if @admin

    edit_organization_registration_sequence_page_path(
      organization_id: organization_param(registration_sequence_page.registration_sequence),
      id: registration_sequence_page.id
    )
  end

  # Leaving the preview: back to the editor, or to the list for a frozen sequence
  def preview_exit(registration_sequence)
    registration_sequence.activated? ? index(registration_sequence) : edit(registration_sequence)
  end

  private

  def organization_param(registration_sequence) = registration_sequence.organization.to_param
end
