# == Schema Information
#
# Table name: users
#
#  id                                 :integer          not null, primary key
#  address_set_manually               :boolean          default(FALSE)
#  admin_options                      :jsonb
#  alert_slugs                        :jsonb
#  auth_token                         :string(255)
#  avatar                             :string(255)
#  banned                             :boolean          default(FALSE), not null
#  can_send_many_stolen_notifications :boolean          default(FALSE), not null
#  city                               :string
#  confirmation_token                 :string(255)
#  confirmed                          :boolean          default(FALSE), not null
#  deleted_at                         :datetime
#  description                        :text
#  developer                          :boolean          default(FALSE), not null
#  email                              :string(255)
#  instagram                          :string
#  last_login_at                      :datetime
#  last_login_ip                      :string
#  latitude                           :float
#  longitude                          :float
#  magic_link_token                   :text
#  my_bikes_hash                      :jsonb
#  name                               :string(255)
#  neighborhood                       :string
#  no_address                         :boolean          default(FALSE)
#  no_non_theft_notification          :boolean          default(FALSE)
#  notification_newsletters           :boolean          default(FALSE), not null
#  notification_unstolen              :boolean          default(TRUE)
#  partner_data                       :jsonb
#  password                           :text
#  password_digest                    :string(255)
#  token_for_password_reset           :text
#  phone                              :string(255)
#  preferred_language                 :string
#  show_bikes                         :boolean          default(FALSE), not null
#  show_instagram                     :boolean          default(FALSE)
#  show_phone                         :boolean          default(TRUE)
#  show_twitter                       :boolean          default(FALSE), not null
#  show_website                       :boolean          default(FALSE), not null
#  street                             :string
#  superuser                          :boolean          default(FALSE), not null
#  terms_of_service                   :boolean          default(FALSE), not null
#  time_single_format                 :boolean          default(FALSE)
#  title                              :text
#  twitter                            :string(255)
#  username                           :string(255)
#  vendor_terms_of_service            :boolean
#  when_vendor_terms_of_service       :datetime
#  zipcode                            :string(255)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  country_id                         :integer
#  state_id                           :integer
#  stripe_id                          :string(255)
#
class Ambassador < User
  default_scope -> { ambassadors }

  # Return all of the receiver's `AmbassadorTaskAssignment`s that are completed
  # and locked.
  def activities_completed
    ambassador_task_assignments
      .includes(:ambassador_task)
      .locked_completed
      .task_ordered
  end

  # Return all of the receiver's `AmbassadorTaskAssignment`s that have not been
  # completed or have been completed but aren't locked.
  def activities_pending
    ambassador_task_assignments
      .includes(:ambassador_task)
      .pending_completion
      .task_ordered
  end

  def percent_complete
    return 0.0 if ambassador_task_assignments.empty?
    (completed_tasks_count / tasks_count.to_f).round(2)
  end

  def progress_count
    "#{completed_tasks_count}/#{tasks_count}"
  end

  def completed_tasks_count
    ambassador_task_assignments.completed.count
  end

  def tasks_count
    ambassador_task_assignments.count
  end

  def ambassador_organizations
    organizations.ambassador
  end

  def current_ambassador_organization
    most_recent_ambassador_membership =
      memberships
        .ambassador_organizations
        .reorder(created_at: :desc)
        .limit(1)

    organizations
      .ambassador
      .where(id: most_recent_ambassador_membership.select(:organization_id))
      .first
  end
end
