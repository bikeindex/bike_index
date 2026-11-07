# The record that a registrant agreed to an organization's e-vehicle safety rules.
# Outlives the registration it came from - the b_param is swept once its bike exists.
# Pending (no acknowledged_at) from when the bike is created until they're agreed to, which
# holds the bike's finished registration email back.
# What was agreed to is read off the sequence, which activation froze.
# == Schema Information
#
# Table name: education_course_acknowledgments
# Database name: primary
#
#  id                  :bigint           not null, primary key
#  acknowledged_at     :datetime
#  owner_email         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  b_param_id          :bigint
#  bike_id             :bigint
#  education_course_id :bigint
#  user_id             :bigint
#
# Indexes
#
#  index_education_course_acknowledgments_on_b_param_id           (b_param_id)
#  index_education_course_acknowledgments_on_bike_id              (bike_id)
#  index_education_course_acknowledgments_on_education_course_id  (education_course_id)
#  index_education_course_acknowledgments_on_user_id              (user_id)
#  index_education_course_acknowledgments_one_per_b_param         (b_param_id) UNIQUE WHERE (b_param_id IS NOT NULL)
#  index_education_course_acknowledgments_pending                 (b_param_id) WHERE (acknowledged_at IS NULL)
#
class EducationCourseAcknowledgment < ApplicationRecord
  # with_deleted: the sequence is soft-deleted with its organization, and this record
  # reads what was agreed to straight off it
  belongs_to :education_course, -> { with_deleted }
  belongs_to :b_param
  belongs_to :bike
  belongs_to :user

  # Not on create: the pending one is made just before its b_param saves the bike,
  # which refreshes the alert anyway
  after_commit(on: %i[update destroy]) { b_param&.update_unfinished_registration_alerts }

  scope :pending, -> { where(acknowledged_at: nil) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }
  scope :for_organization, ->(organization) {
    joins(:education_course).where(education_courses: {organization_id: organization})
  }

  class << self
    # The pages are acknowledged one at a time on the b_param; this is the moment they're
    # agreed to as a whole - onto the pending one when the bike came first, against the
    # sequence the pages were read from rather than the one it was pending on.
    # Whoever is agreeing, over the creator create_bike stood in with
    def acknowledge(b_param, sequence:, user: nil)
      find_or_initialize_by(b_param:).acknowledge!(sequence:, user:)
    end

    def create_pending(b_param, sequence:)
      create(education_course: sequence, b_param:, owner_email: b_param.owner_email)
    end

    # Whether the finished registration email is still waiting on the rules. Only the initial
    # ownership waits: the bike came before them, so a transfer since isn't owed anything
    def holding_email?(ownership)
      ownership.initial? && ownership.bike&.unfinished_registration?
    end

    def abandon_pending(organization_id)
      pending.for_organization(organization_id).each(&:abandon!)
    end

    def find_for(bike:, organization:) = acknowledged.for_organization(organization).where(bike_id: bike.id).last

    def bikes_order(organization:, direction:)
      acknowledged_at = for_organization(organization)
        .where("education_course_acknowledgments.bike_id = bikes.id")
        .select("MAX(education_course_acknowledgments.acknowledged_at)")
      Arel.sql("(#{acknowledged_at.to_sql}) #{(direction == "asc") ? "ASC" : "DESC"}")
    end
  end

  # The review is only reachable with every page acknowledged, so the whole (frozen)
  # sequence is what was agreed to
  def acknowledged_pages
    education_course&.education_course_pages
  end

  def acknowledgment_text
    education_course&.acknowledgment
  end

  def acknowledge!(sequence:, user: nil)
    return false unless update(education_course: sequence, user_id: user&.id || user_id,
      owner_email: b_param.owner_email, acknowledged_at: Time.current)

    release_held_email
    true # Not release_held_email's job id - callers ask whether the write succeeded
  end

  # Given up on rather than agreed to, so the record goes with the rules it was owed against
  def abandon!
    return false unless destroy

    release_held_email
    true
  end

  private

  # The job decides whether it sends. The initial ownership, since that's the one
  # holding_email? withheld
  def release_held_email
    return if bike_id.blank?

    EmailJobs::OwnershipInvitationJob.perform_async(Ownership.initial.where(bike_id:).pick(:id))
  end
end
