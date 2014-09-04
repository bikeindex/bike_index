require 'spec_helper'

describe Ad do
  describe :validations do
    it { should belong_to :organization }
    it { should validate_presence_of :title }
    it { should validate_uniqueness_of :title   }
  end

end
