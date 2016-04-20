require 'spec_helper'

describe Ctype do
  
  describe "import csv" do
    before :each do
      unless Cgroup.where(name: "Drivetrain and brakes").any?
        @component_group = Cgroup.create(name: "Drivetrain and brakes")  
      end
    end

    it "adds component_types to the list" do
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/component-type-test-import.csv")
      expect {
        Ctype.import(import_file)
      }.to change(Ctype, :count).by(2)
    end
    
    it "adds in all the attributes that are listed" do
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/component-type-test-import.csv")
      Ctype.import(import_file)
      @component_type = Ctype.find_by_name("Pedal")
      expect(@component_type.name).to eq('Pedal')
      expect(@component_type.secondary_name).to eq('Wingnut')
      expect(@component_type.cgroup_id).to eq(@component_group.id)
      @component_type2 = Ctype.find_by_slug("wheel")
      expect(@component_type2.secondary_name).to eq('Spinny')
    end

    it "updates attributes on a second upload" do
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/component-type-test-import.csv")
      Ctype.import(import_file)
      second_import_file = File.open(Rails.root.to_s + "/spec/fixtures/component-type-test-import-second.csv")
      Ctype.import(second_import_file)
      @component_type = Ctype.find_by_slug("pedal")
      expect(@component_type.secondary_name).to eq('New name')
    end

  end

end
