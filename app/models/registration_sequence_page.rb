# == Schema Information
#
# Table name: registration_sequence_pages
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  body                     :text
#  heading                  :string
#  listing_order            :integer
#  organization_specific    :boolean          default(FALSE), not null
#  subtitle                 :text
#  title                    :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  registration_sequence_id :bigint           not null
#
# Indexes
#
#  index_registration_sequence_pages_on_registration_sequence_id  (registration_sequence_id)
#
class RegistrationSequencePage < ApplicationRecord
  # with_deleted: a soft-deleted sequence keeps its pages, so they can still be read
  # through it - and the guard below needs to see that it was activated
  belongs_to :registration_sequence, -> { with_deleted }, inverse_of: :registration_sequence_pages

  has_one_attached :image

  validates :title, presence: true
  validate :body_has_content

  # body is HTML from a Lexxy rich-text editor; sanitize to a safe subset on save
  before_validation :sanitize_body
  before_create :set_listing_order
  before_create :prevent_activated_change
  before_update :prevent_activated_change
  before_destroy :prevent_activated_change

  def image_url
    BlobUrl.for(image.blob) if image.attached?
  end

  # The big text at the top of the page. title is the page's name - shown as the
  # label above its rules and in the review - so it stands in when there's no heading
  def heading_text = heading.presence || title

  # body is a single <ul>; the registration flow renders one checkbox per <li>, and the
  # page editor one rich-text row per <li>
  def bullets
    return [] if body.blank?

    items = Nokogiri::HTML.fragment(body).css("li")
    items.any? ? items.map { it.inner_html.strip } : [body.strip]
  end

  private

  # An acknowledgment means every page of its sequence, so activation freezes the set as
  # well as each page - adding one later would rewrite what past registrants agreed to.
  # The cascade from a destroyed organization still goes through.
  def prevent_activated_change
    return unless registration_sequence&.activated?
    # A sequence saved together with its pages is fine - nothing can have acknowledged
    # it yet. What's blocked is changing the pages of one that already existed.
    return if new_record? && registration_sequence.previously_new_record?

    errors.add(:base, "An activated registration sequence's pages can't be changed")
    throw :abort
  end

  # Appended to the end; reordering is done by drag-and-drop on the sequence show page
  def set_listing_order
    self.listing_order ||= (registration_sequence&.registration_sequence_pages&.maximum(:listing_order) || -1) + 1
  end

  def sanitize_body
    self.body = ActionController::Base.helpers.sanitize(body) if body.present?
  end

  # A page is rules to agree to; one with no bullets has nothing to acknowledge
  def body_has_content
    return if Nokogiri::HTML.fragment(body.to_s).text.strip.present?

    errors.add(:body, "needs at least one bullet")
  end
end
