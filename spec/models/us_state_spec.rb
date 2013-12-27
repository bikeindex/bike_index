require 'spec_helper'

describe UsState do
  describe :validations do
    it { should have_many :locations }
    it { should have_many :stolen_records }
    it { should validate_presence_of :name }
    it { should validate_presence_of :abbreviation }
    it { should validate_uniqueness_of :name }
    it { should validate_uniqueness_of :abbreviation }
  end
end
