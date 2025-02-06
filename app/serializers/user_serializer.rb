class UserSerializer < ApplicationSerializer
  attributes :user_present, :is_superuser, :is_content_admin, :memberships

  def memberships
    ActiveModel::ArraySerializer.new(object.organization_roles,
      each_serializer: MembershipSerializer,
      root: false).as_json
  end

  def user_present
    true if object.present?
  end

  def is_superuser
    true if object.superuser?
  end

  def is_content_admin
    false
  end
end
