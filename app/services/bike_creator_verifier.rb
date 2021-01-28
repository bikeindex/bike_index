class BikeCreatorVerifier
  def initialize(b_param = nil, bike = nil)
    @b_param = b_param
    @bike = bike
  end

  def check_organization
    @bike = BikeCreatorOrganizer.new(@b_param, @bike).organized_bike
  end

  def check_example
    example_org = Organization.example
    @bike.creation_organization_id = example_org.id if @b_param.params && @b_param.params["test"]
    if @bike.creation_organization_id.present? && example_org.present?
      @bike.example = true if @bike.creation_organization_id == example_org.id
    else
      @bike.example = false
    end
    @bike
  end

  def verify
    check_organization
    check_example
    @bike
  end
end
