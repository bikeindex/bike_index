require 'spec_helper'

describe TsvCreator do
  
  describe :create_manufacturer do 
    it "makes mnfgs"
  end

  describe :sent_to_uploader do 
    it "sends to uploader" 
  end

  describe :create_organization_count do 
    it "creates tsv with output bikes" do 
      ownership = FactoryGirl.create(:organization_ownership)
      organization = ownership.bike.creation_organization
      creator = TsvCreator.new
      target = "#{creator.org_counts_header}#{creator.org_count_row(ownership.bike)}"
      TsvUploader.any_instance.should_receive(:store!)
      output = creator.create_org_count(organization)
      expect(File.read(output)).to eq(target)
    end
  end

end