require "rails_helper"

RSpec.shared_examples "registration_infoable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }

  describe "student_id" do
    it "is expected" do

    end
  end
end
