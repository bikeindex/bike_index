require 'spec_helper'

describe Paint do
  it { should validate_presence_of :name }
  it { should validate_uniqueness_of :name }
  it { should belong_to :color }
  it { should belong_to :manufacturer }
  it { should have_many :bikes }

  describe "lowercase name" do 
    it "should make the name lowercase on save" do 
      pd = Paint.create(name: "Hazel or Something")
      pd.name.should eq("hazel or something")
    end
  end
end
