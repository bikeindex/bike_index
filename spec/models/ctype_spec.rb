require 'spec_helper'

describe Ctype do
  
  describe "import csv" do
    before :each do
      unless Cgroup.where(name: "Drivetrain and brakes").any?
        @component_group = Cgroup.create(name: "Drivetrain and brakes")  
      end
    end

    it "adds component_types to the list" do
      import_file = File.open(Rails.root.to_s + "/spec/component-type-test-import.csv")
      lambda {
        Ctype.import(import_file)
      }.should change(Ctype, :count).by(2)
    end
    
    it "adds in all the attributes that are listed" do 
      import_file = File.open(Rails.root.to_s + "/spec/component-type-test-import.csv")
      Ctype.import(import_file)
      @component_type = Ctype.find_by_name("Pedal")
      @component_type.name.should eq('Pedal')
      @component_type.secondary_name.should eq('Wingnut')
      @component_type.cgroup_id.should eq(@component_group.id)
      @component_type2 = Ctype.find_by_slug("wheel")
      @component_type2.secondary_name.should eq('Spinny')
    end

    it "updates attributes on a second upload" do 
      import_file = File.open(Rails.root.to_s + "/spec/component-type-test-import.csv")
      Ctype.import(import_file)
      second_import_file = File.open(Rails.root.to_s + "/spec/component-type-test-import-second.csv")
      Ctype.import(second_import_file)
      @component_type = Ctype.find_by_slug("pedal")
      @component_type.secondary_name.should eq('New name')
    end

  end

end
