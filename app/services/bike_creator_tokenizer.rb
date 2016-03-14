class BikeCreatorTokenizer
  def initialize(b_param = nil, bike = nil)
    @b_param = b_param
    @bike = bike 
  end

  def untokenize
    @bike.bike_token_id = nil
    @bike.created_with_token = false
  end

  def use_token(token)
    @bike.created_with_token = true
    @bike.bike_token_id = token.id
    @bike.creation_organization_id = token.organization_id
    @b_param.update_attributes(bike_token_id: token.id)
  end

  def token_usable(token)
    unless token.user == @b_param.creator
      @bike.errors.add(:bike_token, "Uh oh, that free bike ticket doesn't belong to you. Contact us if this is surprising strange!")
      return false
    end
    if token.used?
      @bike.errors.add(:bike_token, "Oh no, you've already used that free bike ticket!")
      return false
    end
    true
  end

  def find_token(bike_token_id)
    begin 
      bike_token = BikeToken.find(bike_token_id)
    rescue ActiveRecord::RecordNotFound
      @bike.errors.add(:bike_token, "Uh oh, we couldn't find that bike token")
      return nil
    end
    bike_token
  end

  def tokenize(bike_token_id)
    bike_token = find_token(bike_token_id)
    if bike_token.present?
      use_token(bike_token) if token_usable(bike_token)
    end
  end

  def check_token
    if @b_param.bike_token_id.present?
      tokenize(@b_param.bike_token_id)
    elsif @b_param.params[:bike_token_id].present?
      tokenize(@b_param.params[:bike_token_id])
    elsif @b_param.params[:bike].present? and @b_param.params[:bike][:bike_token_id]
      tokenize(@b_param.params[:bike][:bike_token_id])
    else
      untokenize
    end
  end
  
  def tokenized_bike
    check_token
    untokenize if @bike.errors[:bike_token].any?
    @bike
  end
end