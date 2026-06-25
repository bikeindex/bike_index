# == Schema Information
#
# Table name: registration_sequences
# Database name: primary
#
#  id              :bigint           not null, primary key
#  approved_at     :datetime
#  status          :integer          default("draft"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  approved_by_id  :bigint
#  organization_id :bigint
#
# A versioned, ordered set of registration pages for an organization. Org admins edit the
# `draft`; a superuser authorizes it `live` via #make_live!, which archives the prior live so
# exactly one stays live until the next is approved. The `template` row (no organization) holds
# the default pages a new draft is seeded from.
class RegistrationSequence < ApplicationRecord
  STATUS_ENUM = {draft: 0, live: 1, archived: 2, template: 3}.freeze

  DEFAULT_PAGES = [
    {
      image_path: "app/assets/images/registration_sequence/register.png",
      body: "## Register your bike\n\n- It only takes a minute\n- Add your serial number and a photo\n- Your registration is free, forever"
    },
    {
      image_path: "app/assets/images/registration_sequence/protect.png",
      body: "## If it's ever stolen\n\n- Mark it stolen in one click\n- We alert the community and local shops\n- Recovered bikes get reunited with their owners"
    }
  ].freeze

  enum :status, STATUS_ENUM

  belongs_to :organization, optional: true
  belongs_to :approved_by, class_name: "User", optional: true

  has_many :pages, -> { order(:listing_order) }, class_name: "RegistrationSequencePage",
    dependent: :destroy, inverse_of: :registration_sequence

  accepts_nested_attributes_for :pages, allow_destroy: true

  class << self
    def template
      sequence = where(status: :template, organization_id: nil).first_or_create!
      seed_default_pages(sequence) if sequence.pages.none?
      sequence
    end

    def live_for(organization)
      where(organization:, status: :live).first
    end

    def draft_for(organization)
      where(organization:, status: :draft).first || build_draft_for(organization)
    end

    private

    def seed_default_pages(sequence)
      DEFAULT_PAGES.each_with_index do |attributes, index|
        sequence.pages.create!(body: attributes[:body], listing_order: index)
      end
    end

    def build_draft_for(organization)
      transaction do
        draft = create!(organization:, status: :draft)
        template.pages.each do |template_page|
          page = draft.pages.create!(body: template_page.body, listing_order: template_page.listing_order)
          page.image.attach(template_page.image.blob) if template_page.image.attached?
        end
        draft
      end
    end
  end

  def make_live!(approver)
    return false unless draft? && pages.any?

    transaction do
      self.class.live_for(organization)&.update!(status: :archived)
      update!(status: :live, approved_by: approver, approved_at: Time.current)
    end
  end
end
