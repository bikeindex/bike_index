require 'spec_helper'

describe Listicle do
  describe :validations do 
    it { should belong_to :blog }
  end

end
