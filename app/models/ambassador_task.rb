class AmbassadorTask < ActiveRecord::Base
  has_many :ambassador_task_assignments
  has_many :users, through: :ambassador_task_assignments

  validates :title, presence: true, uniqueness: true

  def description_html
    Kramdown::Document.new(description).to_html
  end

  def assign_to(user)
    return unless user.ambassador?
    ambassador_task_assignments.create(user: user)
  end

  # Assigns the task to all ambassadors, if not already assigned
  def ensure_assigned_to_all_ambassadors!
    User.ambassadors.find_each do |ambassador|
      next if AmbassadorTaskAssignment.exists?(ambassador_task: self, user: ambassador)
      assign_to(ambassador)
    end
  end
end
