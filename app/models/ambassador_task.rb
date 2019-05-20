class AmbassadorTask < ActiveRecord::Base
  has_many :ambassador_task_assignments
  has_many :users, through: :ambassador_task_assignments

  validates :title, presence: true, uniqueness: true

  after_create :ensure_assigned_to_all_ambassadors!

  def description_html
    Kramdown::Document.new(description).to_html
  end

  # Assign the receiver to the given Ambassador
  # Return the AmbassadorTaskAssignment instance
  def assign_to(user)
    ambassador_task_assignments.create(user: user)
  end

  # Assigns the task to all ambassadors, if not already assigned
  def ensure_assigned_to_all_ambassadors!
    Ambassador.find_each do |ambassador|
      next if ambassador_task_assignments.exists?(user: ambassador)
      assign_to(ambassador)
    end
  end
end
