require 'spec_helper'

describe ColorShade do
  it { should validate_presence_of :name }
  it { should validate_uniqueness_of :name }
  it { should belong_to :color }

  describe "lowercase name" do 
    it "should make the name lowercase" do 
      cs = ColorShade.create(name: "Hazel or Something")
      cs.name.should eq("hazel or something")

    end
  end


end
