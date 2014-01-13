class BikeCreatorVerifier
  def initialize(b_param = nil, bike = nil)
    @b_param = b_param
    @bike = bike 
  end

  def set_no_payment_required
    @bike.payment_required = false
    @bike.verified = true
  end

  def check_token
    @bike = BikeCreatorTokenizer.new(@b_param, @bike).tokenized_bike
  end

  def check_organization
    @bike = BikeCreatorOrganizer.new(@b_param, @bike).organized_bike
  end

  def check_example
    example_org = Organization.find_by_name('Example organization')
    if @bike.creation_organization_id.present? && example_org.present?
      @bike.example = true if @bike.creation_organization_id == example_org.id
    end
    @bike
  end

  def add_phone
    if @bike.creation_organization.present? && @bike.creation_organization.locations.any?
      @bike.phone = @bike.creation_organization.locations.first.phone
    elsif @bike.creator.phone.present?
      @bike.phone = @bike.creator.phone
    end
  end

  def stolenize
    @bike.stolen = true 
    @bike.payment_required = false 
    add_phone
  end

  def recoverize
    @bike.recovered = true 
    @bike.payment_required = false 
    stolenize
  end

  def check_stolen_and_recovered
    if @b_param.params[:stolen]
      stolenize
    elsif @b_param.params[:bike].present? and @b_param.params[:bike][:stolen]
      stolenize
    elsif @b_param.params[:recovered]
      recoverize
    elsif @b_param.params[:bike].present? and @b_param.params[:bike][:recovered]
      recoverize
    end
  end

  def verify
    set_no_payment_required
    check_token
    check_organization
    check_stolen_and_recovered
    check_example
    @bike
  end

end