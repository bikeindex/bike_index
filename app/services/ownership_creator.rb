class OwnershipNotSavedError < StandardError
end

class OwnershipCreator
  def initialize(creation_params = {})
    @creator = creation_params[:creator]
    @bike = creation_params[:bike]
    @owner_email = creation_params[:owner_email]
  end

  def find_owner_email
    @owner_email = @bike.owner_email unless @owner_email.present?
    @owner_email
  end

  def creator_id
    @creator = @bike.creator unless @creator.present?
    @creator.id 
  end

  def owner_id
    user = User.fuzzy_email_find(find_owner_email)
    user.id if user
  end

  def send_notification_email(ownership)
    Resque.enqueue(OwnershipInvitationEmailJob, ownership.id)
  end

  def self_made?
    true if @creator.id == owner_id
  end

  def new_ownership_params
    ownership = {
      bike_id: @bike.id,
      user_id: owner_id,
      owner_email: find_owner_email,
      creator_id: creator_id,
      claimed: self_made?,
      current: true
    }
    ownership
  end

  def mark_other_ownerships_not_current
    if @bike.ownerships.any?
      @bike.ownerships.each do |own|
        own.update_attributes(current: false)
      end
    end
  end

  def add_errors_to_bike(ownership)
    problems = ownership.errors.messages
    problems.each do |message|
      @bike.errors.add(message[0], message[1][0])
    end
    @bike
  end

  def create_ownership
    mark_other_ownerships_not_current
    ownership = Ownership.new(new_ownership_params)
    if ownership.save 
      send_notification_email(ownership)
    else
      add_errors_to_bike(ownership)
      raise OwnershipNotSavedError, "Ownership wasn't saved. Are you sure the bike was created?"
    end
  end

end