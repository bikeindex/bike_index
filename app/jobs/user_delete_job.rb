class UserDeleteJob < ApplicationJob
  # This is called inline - so it makes sense to pass in the user rather than just the user_id
  def perform(user_id, user: nil)
    user ||= User.find(user_id)
    user.bikes.destroy_all
    user.destroy
  end
end
