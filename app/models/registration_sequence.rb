# == Schema Information
#
# Table name: registration_sequences
# Database name: primary
#
#  id              :bigint           not null, primary key
#  end_at          :datetime
#  start_at        :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :bigint
#
# Indexes
#
#  index_registration_sequences_on_organization_id  (organization_id)
#  index_registration_sequences_one_active_per_org  (organization_id) UNIQUE WHERE ((start_at IS NOT NULL) AND (end_at IS NULL))
#  index_registration_sequences_one_draft_per_org   (organization_id) UNIQUE WHERE ((start_at IS NULL) AND (organization_id IS NOT NULL))
#  index_registration_sequences_single_template     (((organization_id IS NULL))) UNIQUE WHERE (organization_id IS NULL)
#
class RegistrationSequence < ApplicationRecord
  STATUS_SCOPES = {"draft" => :draft, "active" => :active, "archived" => :archived, "template" => :templates}.freeze
  STATUSES = STATUS_SCOPES.keys.freeze

  belongs_to :organization, optional: true

  has_many :registration_sequence_pages, -> { order(:listing_order) },
    dependent: :destroy, inverse_of: :registration_sequence

  scope :templates, -> { where(organization_id: nil) }
  scope :draft, -> { where(start_at: nil).where.not(organization_id: nil) }
  scope :active, -> { where.not(start_at: nil).where(end_at: nil) }
  scope :archived, -> { where.not(start_at: nil).where.not(end_at: nil) }

  class << self
    # first_or_create! and build_draft_for are guarded only by partial unique indexes;
    # a concurrent request can win the create race, so re-read the row it inserted.
    def template
      templates.first_or_create!
    rescue ActiveRecord::RecordNotUnique
      templates.first!
    end

    def active_for(organization)
      active.find_by(organization:)
    end

    def draft_for(organization)
      draft.find_by(organization:) || build_draft_for(organization)
    rescue ActiveRecord::RecordNotUnique
      draft.find_by!(organization:)
    end

    def for_status(status)
      scope = STATUS_SCOPES[status.to_s]
      scope ? public_send(scope) : all
    end

    private

    def build_draft_for(organization)
      transaction do
        draft = create!(organization:)
        template.registration_sequence_pages.each do |template_page|
          page = draft.registration_sequence_pages.create!(title: template_page.title, subtitle: template_page.subtitle, body: template_page.body, listing_order: template_page.listing_order)
          page.image.attach(template_page.image.blob) if template_page.image.attached?
        end
        draft
      end
    end
  end

  def template? = organization_id.blank?

  def draft? = organization_id.present? && start_at.blank?

  def active? = start_at.present? && end_at.blank?

  def archived? = start_at.present? && end_at.present?

  def status
    return "template" if template?
    return "active" if active?
    return "archived" if archived?

    "draft"
  end

  # Reorders pages to match the given ids (drag-and-drop on the show page)
  def reorder_pages!(ordered_ids)
    Array(ordered_ids).each_with_index do |page_id, index|
      registration_sequence_pages.where(id: page_id).update_all(listing_order: index)
    end
  end

  def make_active!
    return false unless draft? && registration_sequence_pages.any?

    transaction do
      self.class.active_for(organization)&.update!(end_at: Time.current)
      update!(start_at: Time.current)
    end
  end
end
