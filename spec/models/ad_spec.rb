require 'spec_helper'

describe Ad do
  describe :validations do
    it { should belong_to :organization }
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :name   }
  end

end
