class AmbassadorTask < ActiveRecord::Base
  has_many :ambassador_task_assignments
  has_many :ambassadors, through: :ambassador_task_assignments

  validates :title, presence: true, uniqueness: true

  scope :task_ordered, -> { order(id: :asc) }

  after_create :ensure_assigned_to_all_ambassadors!

  def description_html
    Kramdown::Document.new(description).to_html
  end

  # Assign the receiver to the given Ambassador
  # Return the AmbassadorTaskAssignment instance
  def assign_to(ambassador)
    ambassador_task_assignments.create(ambassador: ambassador)
  end

  # Assigns the task to all ambassadors, if not already assigned
  def ensure_assigned_to_all_ambassadors!
    AmbassadorTaskAfterCreateWorker.perform_async(id)
  end
end
