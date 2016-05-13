class BikeCreatorVerifier
  def initialize(bikeParam = nil, bike = nil)
    @bikeParam = bikeParam
    @bike = bike
  end

  def check_organization
    @bike = BikeCreatorOrganizer.new(@bikeParam, @bike).organized_bike
  end

  def check_example
    example_org = Organization.find_by_name('Example organization')
    @bike.creation_organization_id = example_org.id if @bikeParam.params && @bikeParam.params[:test]
    if @bike.creation_organization_id.present? && example_org.present?
      @bike.example = true if @bike.creation_organization_id == example_org.id
    else
      @bike.example = false
    end
    @bike
  end

  def add_phone
    @bike.phone ||= @bikeParam.params[:stolenRecord][:phone] if @bikeParam.params && @bikeParam.params[:stolenRecord].present?
    if @bike.creation_organization.present? && @bike.creation_organization.locations.any?
      @bike.phone ||= @bike.creation_organization.locations.first.phone
    elsif @bike.creator.phone.present?
      @bike.phone ||= @bike.creator.phone
    end
  end

  def stolenize
    @bike.stolen = true
    add_phone unless @bike.phone.present?
  end

  def recoverize
    @bike.recovered = true
    stolenize
  end

  def check_stolen_and_recovered
    if @bikeParam.params[:stolen]
      stolenize
    elsif @bikeParam.params[:bike].present? and @bikeParam.params[:bike][:stolen]
      stolenize
    elsif @bikeParam.params[:recovered]
      recoverize
    elsif @bikeParam.params[:bike].present? and @bikeParam.params[:bike][:recovered]
      recoverize
    end
  end

  def verify
    check_organization
    check_stolen_and_recovered
    check_example
    @bike
  end
end
