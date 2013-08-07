require 'spec_helper'

describe Color do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :name }
  end
end
