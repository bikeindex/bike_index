# == Schema Information
#
# Table name: organization_roles
#
#  id                       :integer          not null, primary key
#  claimed_at               :datetime
#  created_by_magic_link    :boolean          default(FALSE)
#  deleted_at               :datetime
#  email_invitation_sent_at :datetime
#  hot_sheet_notification   :integer          default("notification_never")
#  invited_email            :string(255)
#  receive_hot_sheet        :boolean          default(FALSE)
#  role                     :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  organization_id          :integer          not null
#  sender_id                :integer
#  user_id                  :integer
#
# Indexes
#
#  index_organization_roles_on_organization_id  (organization_id)
#  index_organization_roles_on_sender_id        (sender_id)
#  index_organization_roles_on_user_id          (user_id)
#
class OrganizationRoleSerializer < ApplicationSerializer
  attributes :organization_name,
    :organization_id,
    :short_name,
    :slug,
    :is_admin,
    :base_url,
    :locations

  def organization_name
    object.organization.name
  end

  def short_name
    object.organization.short_name
  end

  def organization_id
    object.organization.id
  end

  def slug
    object.organization.slug
  end

  def is_admin
    object.role == "admin"
  end

  def base_url
    "/organizations/#{object.organization.slug}"
  end

  def locations
    if object.organization.locations && object.organization.locations.length > 1
      object.organization.locations.map do |location|
        {name: location.name, id: location.id}
      end
    else
      [{name: organization_name, id: nil}]
    end
  end
end
