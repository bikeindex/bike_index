# == Schema Information
#
# Table name: registration_sequences
# Database name: primary
#
#  id                  :bigint           not null, primary key
#  acknowledgment_text :text
#  deleted_at          :datetime
#  end_at              :datetime
#  faq_url             :string
#  kind                :integer          default("e_vehicle"), not null
#  start_at            :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  organization_id     :bigint
#
# Indexes
#
#  index_registration_sequences_on_deleted_at        (deleted_at)
#  index_registration_sequences_on_organization_id   (organization_id)
#  index_registration_sequences_one_active_per_org   (organization_id,kind) UNIQUE WHERE ((start_at IS NOT NULL) AND (end_at IS NULL) AND (deleted_at IS NULL))
#  index_registration_sequences_one_active_template  (((organization_id IS NULL)), kind) UNIQUE WHERE ((organization_id IS NULL) AND (start_at IS NOT NULL) AND (end_at IS NULL) AND (deleted_at IS NULL))
#  index_registration_sequences_one_draft_per_org    (organization_id,kind) UNIQUE WHERE ((start_at IS NULL) AND (organization_id IS NOT NULL) AND (deleted_at IS NULL))
#  index_registration_sequences_one_draft_template   (((organization_id IS NULL)), kind) UNIQUE WHERE ((organization_id IS NULL) AND (start_at IS NULL) AND (deleted_at IS NULL))
#
class RegistrationSequence < ApplicationRecord
  acts_as_paranoid

  # An owner has one sequence of each kind, drafted and activated independently
  KIND_ENUM = {e_vehicle: 0, non_e_vehicle: 1}.freeze
  KINDS = KIND_ENUM.keys.map(&:to_s).freeze
  # The admin index's filters. "template" is which sequence rather than which status - a
  # template is drafted, activated and archived like an organization's
  STATUS_SCOPES = {"draft" => :draft, "active" => :active, "archived" => :archived, "template" => :templates}.freeze
  STATUSES = STATUS_SCOPES.keys.freeze
  COPIED_PAGE_ATTRS = %w[title heading subtitle body listing_order organization_specific].freeze
  # Follows "I, <registrant's name>," on the flow's final acknowledgment. Seeded onto each
  # template, so an organization edits its own copy
  DEFAULT_ACKNOWLEDGMENT_TEXT = "have read, understood, and agree to comply with all of the " \
    "%{rules} above as a condition of registering my vehicle. I understand that failure to " \
    "comply may result in revocation of my registration and/or disciplinary action."
  DEFAULT_ACKNOWLEDGMENT_RULES = {"e_vehicle" => "e-vehicle safety rules",
                                  "non_e_vehicle" => "safety rules"}.freeze

  # What each status is called on screen
  STATUS_DISPLAY = {"draft" => "Draft", "active" => "Current", "archived" => "Previous"}.freeze
  # What each kind is called on the admin and organization screens. The registrant flow
  # names them in its own translations instead
  KIND_DISPLAY = {"e_vehicle" => "E-Vehicle", "non_e_vehicle" => "Non-e-vehicle"}.freeze
  # Both the admin and the organization screens warn with this before discarding
  DISCARD_DRAFT_CONFIRM = "Discard this draft and its pages? This can't be undone."

  enum :kind, KIND_ENUM

  belongs_to :organization

  # with_attached_image: every reader of the pages renders or copies their images
  has_many :registration_sequence_pages, -> { order(:listing_order).with_attached_image },
    inverse_of: :registration_sequence
  # an acknowledgment is a record of what someone agreed to, don't remove the record
  has_many :registration_sequence_acknowledgments

  before_update :prevent_activated_change

  scope :templates, -> { where(organization_id: nil) }
  # Everything activation hasn't frozen
  scope :draft, -> { where(start_at: nil) }
  scope :active, -> { where.not(start_at: nil).where(end_at: nil) }
  scope :archived, -> { where.not(start_at: nil).where.not(end_at: nil) }

  class << self
    # The template belongs to no organization, so nil is its owner in every lookup here
    def active_template(kind:) = active_for(nil, kind:)

    def active_for(organization, kind:)
      active.find_by(organization:, kind:)
    end

    # What a draft is cloned from, and what the registration flow shows: the owner's live
    # sequence, falling back to the template every organization starts from
    def active_or_template_for(organization, kind:)
      active_for(organization, kind:) || active_template(kind:)
    end

    # The draft as it stands - draft_for opens one when there isn't one
    def existing_draft_for(organization, kind:) = draft.find_by(organization:, kind:)

    # build_draft_for is guarded only by a partial unique index; a concurrent request can
    # win the create race, so re-read the row it inserted.
    def draft_for(organization, kind:)
      existing_draft_for(organization, kind:) || build_draft_for(organization, kind:)
    rescue ActiveRecord::RecordNotUnique
      draft.find_by!(organization:, kind:)
    end

    def for_status(status)
      scope = STATUS_SCOPES[status.to_s]
      scope ? public_send(scope) : all
    end

    # A link without a kind means e-vehicle; one that isn't a kind 404s rather than
    # quietly opening the wrong sequence
    def permitted_kind(kind)
      return "e_vehicle" if kind.blank?

      KINDS.include?(kind.to_s) ? kind.to_s : raise(ActiveRecord::RecordNotFound)
    end

    def kind_display(kind) = KIND_DISPLAY[kind.to_s]

    def default_acknowledgment(kind)
      format(DEFAULT_ACKNOWLEDGMENT_TEXT, rules: DEFAULT_ACKNOWLEDGMENT_RULES[kind.to_s])
    end

    private

    # Start the draft from what's live so an edit tweaks the current sequence rather than
    # discarding the organization's customizations. Nothing sits above the template, so its
    # very first draft starts empty.
    def build_draft_for(organization, kind:)
      source = active_or_template_for(organization, kind:)
      transaction do
        draft = create!(organization:, kind:, faq_url: source&.faq_url,
          acknowledgment_text: source&.acknowledgment_text)
        source&.registration_sequence_pages&.each do |source_page|
          page = draft.registration_sequence_pages.create!(source_page.slice(*COPIED_PAGE_ATTRS))
          copy_image(source_page.image, page.image) if source_page.image.attached?
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

  def acknowledgment = acknowledgment_text.presence || default_acknowledgment

  def default_acknowledgment = self.class.default_acknowledgment(kind)

  def template? = organization_id.blank?

  def draft? = start_at.blank?

  def active? = start_at.present? && end_at.blank?

  def archived? = start_at.present? && end_at.present?

  def status
    return "active" if active?
    return "archived" if archived?

    "draft"
  end

  def status_display = STATUS_DISPLAY[status]

  def kind_display = self.class.kind_display(kind)

  # Which sequence this is, e.g. "Brakebills E-Vehicle Current" or "Template Non-e-vehicle Draft"
  def display_name = "#{badge_name} #{kind_display} #{status_display}"

  # Who this sequence belongs to - badges an organization-specific page, and names the
  # sequence in display_name
  def badge_name = organization&.short_name || "Template"

  # Activation freezes the sequence and its pages. Acknowledgments reference them by id, so
  # what a registrant agreed to has to keep saying the same thing - a change belongs in a
  # new draft, which activating supersedes this with.
  def activated? = !draft?

  # Moves page to position and re-sequences listing_order (drag-and-drop on the show page).
  # update_all skips the pages' own callbacks, so the guard is here too
  def reorder_page!(page, position)
    return false if activated?

    others = registration_sequence_pages.where.not(id: page.id).order(:listing_order).to_a
    others.insert(position.clamp(0, others.length), page).each_with_index do |reordered_page, index|
      registration_sequence_pages.where(id: reordered_page.id).update_all(listing_order: index)
    end
  end

  def make_active!
    pages = registration_sequence_pages.to_a
    return false unless draft? && pages.any? && pages.all?(&:valid?)

    transaction do
      self.class.active_for(organization, kind:)&.update!(end_at: Time.current)
      update!(start_at: Time.current)
    end
  end

  # Throw an unactivated draft away entirely, pages and all. Unlike an archived sequence,
  # nothing has acknowledged it, so there's nothing to preserve.
  def discard_draft!
    return false if activated?

    transaction do
      registration_sequence_pages.destroy_all
      really_destroy!
    end
  end

  private

  # Keyed off the persisted start_at, so activation itself still goes through -
  # afterward only archiving (end_at) is allowed
  def prevent_activated_change
    return if start_at_in_database.blank? || (changed - %w[end_at updated_at]).none?

    errors.add(:base, "An activated registration sequence can't be edited — start a new draft")
    throw :abort
  end
end
