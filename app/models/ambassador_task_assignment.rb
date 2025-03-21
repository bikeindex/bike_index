# == Schema Information
#
# Table name: ambassador_task_assignments
#
#  id                 :integer          not null, primary key
#  completed_at       :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ambassador_task_id :integer          not null
#  user_id            :integer          not null
#
# Indexes
#
#  index_ambassador_task_assignments_on_ambassador_task_id  (ambassador_task_id)
#  unique_assignment_to_ambassador                          (user_id,ambassador_task_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ambassador_task_id => ambassador_tasks.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class AmbassadorTaskAssignment < ApplicationRecord
  belongs_to :ambassador_task
  belongs_to :ambassador,
    class_name: "Ambassador",
    foreign_key: :user_id,
    primary_key: :id

  validates :ambassador, presence: true
  validates :ambassador_task, presence: true

  validates :ambassador_task, uniqueness: {scope: :ambassador}

  scope :completed, -> { where.not(completed_at: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :pending_completion, -> { incomplete.or(where("completed_at > ?", Time.current - 2.hours)) }
  scope :locked_completed, -> { completed.where("completed_at < ?", Time.current - 2.hours) }
  scope :task_ordered, -> { order(ambassador_task_id: :asc) }

  after_commit :update_associated_user

  delegate :description, :description_html, :title, to: :ambassador_task
  delegate :name, to: :ambassador, prefix: true, allow_nil: true
  delegate :name, to: :organization, prefix: true, allow_nil: true

  # Find completed assignments, filtering and sorting by columns on associated
  # models. The inner join is necessary because our data model permits multiple
  # ambassador organization_roles for the same user (the most recent being
  # the active ambassadorship). The intent is to eventually refactor to
  # enforcing single user role.
  #
  # filters: :organization_id, :ambassador_task_id, :ambassador_id (multiple permitted)
  # sort: :organization_name, :ambassador_task_title, :ambassador_name
  #
  # Example:
  #
  #    AmbassadorTaskAssignment.completed_assignments(
  #      filters: { organization_id: 3, ambassador_task_id: 1 },
  #      sort: { ambassador_task_title: :desc }
  #    )
  #
  # Return [AmbassadorTaskAssignment]
  def self.completed_assignments(filters: {}, sort: {})
    filters = filters.each_pair.map { |col, val| [col.to_s.to_sym, sanitize_sql(val)] }
    sort_col, sort_dir = sort.to_a.first
    sort_col = (sort_col || "").to_sym

    query = "".tap do |sql|
      sql << <<~SQL
        SELECT *, ambassador_task_assignments.id as id
        FROM ambassador_task_assignments
        JOIN ambassador_tasks
        ON ambassador_tasks.id = ambassador_task_assignments.ambassador_task_id
        JOIN users
        ON users.id = ambassador_task_assignments.user_id
        JOIN (
            SELECT m.user_id, MAX(m.created_at) AS created_at
            FROM organization_roles AS m
            JOIN organizations AS o
            ON m.organization_id = o.id
            WHERE o.kind = #{Organization.kinds.index("ambassador")}
            AND o.deleted_at IS NULL
            GROUP BY m.user_id
        ) current_ambassadorships
        ON current_ambassadorships.user_id = users.id
        JOIN organization_roles
        ON organization_roles.created_at = current_ambassadorships.created_at
        JOIN organizations
        ON organization_roles.organization_id = organizations.id
        WHERE ambassador_task_assignments.completed_at IS NOT NULL
      SQL

      filter_to_sql_clause = {
        organization_id: ->(filter_val) { "AND organizations.id = #{filter_val} " },
        ambassador_task_id: ->(filter_val) { "AND ambassador_tasks.id = #{filter_val} " },
        ambassador_id: ->(filter_val) { "AND users.id = #{filter_val} " }
      }
      sql << filters
        .map { |col, val| filter_to_sql_clause[col]&.call(val) }
        .join("\n")

      sql << case sort_col
      when :organization_name
        "ORDER BY organizations.name #{sort_dir.upcase}\n"
      when :completed_at
        "ORDER BY ambassador_task_assignments.completed_at #{sort_dir.upcase}\n"
      when :ambassador_task_title
        "ORDER BY ambassador_tasks.title #{sort_dir.upcase}\n"
      when :ambassador_name
        "ORDER BY users.name #{sort_dir.upcase}\n"
      else
        "ORDER BY ambassador_task_assignments.completed_at DESC\n"
      end
    end

    find_by_sql(query)
  end

  def organization
    ambassador.current_ambassador_organization
  end

  def completed?
    completed_at.present?
  end

  def update_associated_user
    ambassador.update(updated_at: Time.current)
  end
end
