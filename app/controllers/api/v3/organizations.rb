module API
  module V3
    class Organizations < API::Base
      resource :organizations do
        desc "Add an Organization to Bike Index", {
          authorizations: { oauth2: [{ scope: :write_organizations }] },
          notes: <<-NOTES
            ...
          NOTES
        }
        params do
          requires :name, type: String, desc: "The organization name"
          requires :website, type: String, desc: "The organization website", regexp: URI::regexp(%w(http https))
          requires :kind, type: String, desc: "The kind of organization", values: Organization.kinds
          optional :location, type: Hash, desc: "An organization location" do
            requires :street, type: String, desc: "The location's street"
            requires :city, type: String, desc: "The location's city"
            requires :state, type: String, desc: "The location's state", values: State.valid_names
            requires :country, type: String, desc: "The location's country", values: Country.valid_names
            requires :zipcode, type: String, desc: "The location's zipcode"
          end 
        end

        # POST /api/v3/organizations
        post serializer: OrganizationSerializer, root: 'organization' do
          # ... params.merge(auto_user_id: current_user.id)
          Organization.last
        end
      end
    end
  end
end