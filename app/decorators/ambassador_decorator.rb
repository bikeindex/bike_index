class AmbassadorDecorator < ApplicationDecorator
  delegate_all
  alias ambassador object

  def ambassador_task_assignments
    ambassador
      .ambassador_task_assignments
      .order(created_at: :asc)
  end

  def avatar
    avatar_url = ambassador.avatar&.url(:medium)
    return if avatar_url.blank? || avatar_url == "https://files.bikeindex.org/blank.png"
    h.image_tag avatar_url, class: "users-show-avatar"
  end
end
