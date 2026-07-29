# == Schema Information
#
# Table name: registration_sequences
# Database name: primary
#
#  id               :bigint           not null, primary key
#  attestation_text :text
#  end_at           :datetime
#  faq_url          :string
#  start_at         :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  organization_id  :bigint
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
  COPIED_PAGE_ATTRS = %w[title subtitle body listing_order organization_specific].freeze
  # Follows "I, <registrant's name>," on the flow's final attestation. Seeded onto the
  # template, so an organization edits its own copy
  DEFAULT_ATTESTATION_TEXT = "have read, understood, and agree to comply with all of the " \
    "e-vehicle safety rules above as a condition of registering my vehicle. I understand that " \
    "failure to comply may result in revocation of my registration."

  belongs_to :organization, optional: true

  # with_attached_image: every reader of the pages renders or copies their images
  has_many :registration_sequence_pages, -> { order(:listing_order).with_attached_image },
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
        source = template
        draft = create!(organization:, faq_url: source.faq_url, attestation_text: source.attestation_text)
        source.registration_sequence_pages.each do |template_page|
          page = draft.registration_sequence_pages.create!(template_page.slice(*COPIED_PAGE_ATTRS))
          copy_image(template_page.image, page.image) if template_page.image.attached?
        end
        draft
      end
    end

    # Duplicate into a new blob; attaching the source blob directly would share it,
    # so purging either record's image (page/sequence/org destroy) would break the other.
    def copy_image(source, target)
      blob = source.blob
      target.attach(io: StringIO.new(blob.download), filename: blob.filename, content_type: blob.content_type)
    end
  end

  def attestation = attestation_text.presence || DEFAULT_ATTESTATION_TEXT

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

  # Moves page to position and re-sequences listing_order (drag-and-drop on the show page)
  def reorder_page!(page, position)
    others = registration_sequence_pages.where.not(id: page.id).order(:listing_order).to_a
    others.insert(position.clamp(0, others.length), page).each_with_index do |reordered_page, index|
      registration_sequence_pages.where(id: reordered_page.id).update_all(listing_order: index)
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
