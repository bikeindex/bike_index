require 'spec_helper'

describe OtherListing do
  describe :validations do 
    it { should validate_presence_of :bike_id }
    it { should validate_presence_of :url }
    it { should belong_to :bike }
  end

end
