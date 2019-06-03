class AmbassadorTaskAssignment < ActiveRecord::Base
  belongs_to :ambassador_task
  belongs_to :ambassador,
             class_name: "Ambassador",
             foreign_key: :user_id

  validates :ambassador, presence: true
  validates :ambassador_task, presence: true

  validates :ambassador_task, uniqueness: { scope: :ambassador }

  scope :completed, -> { where.not(completed_at: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :pending_completion, -> { incomplete.or(where("completed_at > ?", Time.now - 2.hours)) }
  scope :locked_completed, -> { completed.where("completed_at < ?", Time.now - 2.hours) }
  scope :task_ordered, -> { order(ambassador_task_id: :asc) }

  after_commit :update_associated_user

  delegate :description, :description_html, :title, to: :ambassador_task
  delegate :name, to: :ambassador, prefix: true

  def organization_name
    ambassador.current_ambassador_organization&.name
  end

  def completed?
    completed_at.present?
  end

  def update_associated_user
    ambassador.update_attributes(updated_at: Time.now)
  end
end
