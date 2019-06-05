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
  delegate :name, to: :organization, prefix: true

  def self.completed_assignments(filter = {}, sort = {})
    filter_col, filter_val = filter.to_a.first
    sort_col, sort_dir = sort.to_a.first
    filter_col, sort_col = filter_col.to_s.to_sym, sort_col.to_s.to_sym

    query = "".tap do |sql|
      sql << <<~SQL
        SELECT *
        FROM ambassador_task_assignments
        JOIN ambassador_tasks
        ON ambassador_tasks.id = ambassador_task_assignments.ambassador_task_id
        JOIN users
        ON users.id = ambassador_task_assignments.user_id
        JOIN (
            SELECT m.user_id, MAX(m.created_at) AS created_at
            FROM memberships AS m
            JOIN organizations AS o
            ON m.organization_id = o.id
            WHERE o.kind = #{Organization.kinds.index("ambassador")}
            AND o.deleted_at IS NULL
            GROUP BY m.user_id
        ) current_ambassadorships
        ON current_ambassadorships.user_id = users.id
        JOIN memberships
        ON memberships.created_at = current_ambassadorships.created_at
        JOIN organizations
        ON memberships.organization_id = organizations.id
        WHERE ambassador_task_assignments.completed_at IS NOT NULL
      SQL

      if filter_val.present?
        case filter_col
        when :organization_id
          sql << "\n AND organizations.id = #{filter_val}"
        when :ambassador_task_id
          sql << "\n AND ambassador_tasks.id = #{filter_val}"
        when :ambassador_id
          sql << "\n AND users.id = #{filter_val}"
        end
      end

      case sort_col
      when :organization_name
        sql << "\n ORDER BY organizations.name #{sort_dir}"
      when :completed_at
        sql << "\n ORDER BY ambassador_task_assignments.completed_at #{sort_dir}"
      when :task_title
        sql << "\n ORDER BY ambassador_tasks.title #{sort_dir}"
      when :ambassador_name
        sql << "\n ORDER BY users.name #{sort_dir}"
      else
        sql << "\n ORDER BY ambassador_task_assignments.ambassador_task_id ASC"
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
    ambassador.update_attributes(updated_at: Time.now)
  end
end
