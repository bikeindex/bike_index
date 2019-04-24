class OwnershipNotSavedError < StandardError
end

class OwnershipCreator
  def initialize(creation_params = {})
    @creator = creation_params[:creator]
    @bike = creation_params[:bike]
    @owner_email = creation_params[:owner_email]
    @send_email = creation_params[:send_email]
    @user_hidden = creation_params[:user_hidden]
  end

  def creator_id
    @creator_id ||= @bike.creator&.id
  end

  def user_id
    @user_id ||= User.fuzzy_email_find(@bike.owner_email)&.id
  end

  def send_notification_email(ownership)
    return true if ownership.example
    return true unless ownership.send_email
    EmailOwnershipInvitationWorker.perform_in(30.seconds, ownership.id)
  end

  def self_made?
    true if creator_id == user_id
  end

  def new_ownership_params
    {
      bike_id: @bike.id,
      user_id: user_id,
      owner_email: @bike.owner_email,
      creator_id: creator_id,
      claimed: self_made?,
      example: @bike.example,
      current: true,
      send_email: @send_email,
      user_hidden: @user_hidden,
    }
  end

  def mark_other_ownerships_not_current
    return true unless @bike.ownerships.any?
    @bike.ownerships.each do |own|
      own.update_attributes(current: false)
    end
  end

  def add_errors_to_bike(ownership)
    problems = ownership.errors.messages
    problems.each do |message|
      @bike.errors.add(message[0], message[1][0])
    end
    @bike
  end

  def current_is_hidden
    @bike&.user_hidden
  end

  def create_ownership
    @user_hidden = current_is_hidden
    mark_other_ownerships_not_current
    ownership = Ownership.new(new_ownership_params)

    if ownership.save
      send_notification_email(ownership)
    else
      add_errors_to_bike(ownership)
      raise OwnershipNotSavedError, "Ownership wasn't saved. Are you sure the bike was created?"
    end
    ownership
  end
end
