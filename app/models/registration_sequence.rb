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
#  approved_by_id  :bigint
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
  STATUSES = %w[draft active archived template].freeze

  belongs_to :organization, optional: true
  belongs_to :approved_by, class_name: "User", optional: true

  has_many :registration_sequence_pages, -> { order(:listing_order) },
    dependent: :destroy, inverse_of: :registration_sequence

  accepts_nested_attributes_for :registration_sequence_pages, allow_destroy: true

  scope :templates, -> { where(organization_id: nil) }
  scope :draft, -> { where(start_at: nil).where.not(organization_id: nil) }
  scope :active, -> { where.not(start_at: nil).where(end_at: nil) }
  scope :archived, -> { where.not(start_at: nil).where.not(end_at: nil) }

  class << self
    def template
      templates.first_or_create!
    end

    def active_for(organization)
      active.find_by(organization:)
    end

    def draft_for(organization)
      draft.find_by(organization:) || build_draft_for(organization)
    end

    def for_status(status)
      if STATUSES.include?(status.to_s)
        public_send((status == "template") ? :templates : status)
      else
        all
      end
    end

    private

    def build_draft_for(organization)
      transaction do
        draft = create!(organization:)
        template.registration_sequence_pages.each do |template_page|
          page = draft.registration_sequence_pages.create!(bullet_points: template_page.bullet_points, listing_order: template_page.listing_order)
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
    return "draft" if start_at.blank?

    end_at.blank? ? "active" : "archived"
  end

  def make_active!(approver)
    return false unless draft? && registration_sequence_pages.any?

    transaction do
      self.class.active_for(organization)&.update!(end_at: Time.current)
      update!(start_at: Time.current, approved_by: approver)
    end
  end
end
