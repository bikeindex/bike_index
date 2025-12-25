# == Schema Information
#
# Table name: versions
# Database name: analytics
#
#  id             :bigint           not null, primary key
#  event          :string           not null
#  item_type      :string           not null
#  object         :jsonb
#  object_changes :jsonb
#  whodunnit      :string
#  created_at     :datetime
#  item_id        :bigint           not null
#
# Indexes
#
#  index_versions_on_item_type_and_item_id  (item_type,item_id)
#
class Version < AnalyticsRecord
  include PaperTrail::VersionConcern
end
