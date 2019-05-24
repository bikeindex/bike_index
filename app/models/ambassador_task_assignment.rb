class AmbassadorTaskAssignment < ActiveRecord::Base
  belongs_to :user
  belongs_to :ambassador_task

  validates :user, presence: true
  validates :ambassador_task, presence: true

  validates :ambassador_task, uniqueness: { scope: :user }
  validate :associated_user_is_an_ambassador

  delegate :description, :description_html, :title, to: :ambassador_task

  scope :completed, -> { where.not(completed_at: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :pending_completion, -> { incomplete.or(where("completed_at > ?", Time.now - 2.hours)) }
  scope :locked_completed, -> { completed.where("completed_at < ?", Time.now - 2.hours) }
  scope :task_ordered, -> { order(ambassador_task_id: :asc) }

  def status
    completed? ? "Completed" : "In progress"
  end

  def completed?
    completed_at.present?
  end

  private

  def associated_user_is_an_ambassador
    return if user&.ambassador?
    errors.add(:user, "must be an ambassador")
  end
end
