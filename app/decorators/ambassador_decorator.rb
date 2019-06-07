# NB: Decorators are deprecated in this project.
#     Use Helper methods for view logic, consider incrementally refactoring
#     existing view logic from decorators to view helpers.
class AmbassadorDecorator < ApplicationDecorator
  delegate_all

  def avatar
    avatar_url = ambassador.avatar&.url(:medium)
    return if avatar_url.blank? || avatar_url == "https://files.bikeindex.org/blank.png"
    h.image_tag avatar_url, class: "users-show-avatar"
  end
end
