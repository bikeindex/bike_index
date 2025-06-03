require "rails_helper"

RSpec.shared_examples "registration_infoable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create(model_sym, registration_info: registration_info) }
  let(:registration_info) { {} }

  describe "scoping" do
    let(:registration_info) { {student_id: "12", organization_affiliation: "student"} }
    let(:registration_info2) { {"student_id_#{organization.id}" => "42", "organization_affiliation_#{organization.id}" => "employee"} }
    let!(:instance2) { FactoryBot.create(model_sym, registration_info: registration_info2) }
    let!(:instance3) { FactoryBot.create(model_sym, registration_info: {user_name: "party", organization_affiliation: "1"}) }
    let(:organization) { FactoryBot.create(:organization) }
    it "is expected" do
      expect(instance.student_id).to eq "12"
      expect(instance.student_id(organization.id)).to eq "12"
      expect(instance.organization_affiliation).to eq "student"
      expect(instance.organization_affiliation(organization.slug)).to eq "student"
      expect(subject.class.pluck(:id)).to match_array([instance.id, instance2.id, instance3.id])
      expect(subject.class.with_student_id(organization).pluck(:id)).to match_array([instance.id, instance2.id])
      expect(subject.class.with_student_id(organization.id).pluck(:id)).to match_array([instance.id, instance2.id])
      expect(subject.class.with_student_id(organization.id + 2222).pluck(:id)).to match_array([instance.id])

      expect(subject.class.with_organization_affiliation(organization).pluck(:id)).to match_array([instance.id, instance2.id, instance3.id])
      expect(subject.class.with_organization_affiliation(organization.id).pluck(:id)).to match_array([instance.id, instance2.id, instance3.id])
      expect(subject.class.with_organization_affiliation(organization.id + 2222).pluck(:id)).to match_array([instance.id, instance3.id])
    end
  end

  describe "true_false_question" do
    let(:registration_info2) { {"true_false_question_#{organization.id}" => "true"} }
    let!(:instance2) { FactoryBot.create(model_sym, registration_info: registration_info2) }
    let(:organization) { FactoryBot.create(:organization) }
    it "is expected" do
      expect(instance.true_false_question).to be_nil
      expect(instance.true_false_question(organization.id)).to be_nil
      expect(instance2.true_false_question).to eq "true"
      expect(instance2.true_false_question(organization.id)).to eq "true"
      # expect(instance.organization_affiliation).to eq "student"
      # expect(instance.organization_affiliation(organization.slug)).to eq "student"
      expect(subject.class.pluck(:id)).to match_array([instance.id, instance2.id])
      expect(subject.class.with_true_false_question(organization).pluck(:id)).to match_array([instance2.id])
      expect(subject.class.with_true_false_question(organization.id).pluck(:id)).to match_array([instance2.id])

      instance.true_false_question = false, organization
      expect(instance.reload.true_false_question).to eq 'false'
    end
  end
end
