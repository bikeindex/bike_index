# == Schema Information
#
# Table name: listicles
#
#  id                 :integer          not null, primary key
#  body               :text
#  body_html          :text
#  crop_top_offset    :integer
#  image              :string(255)
#  image_credits      :text
#  image_credits_html :text
#  image_height       :integer
#  image_width        :integer
#  list_order         :integer
#  title              :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  blog_id            :integer
#
require "rails_helper"

RSpec.describe Listicle, type: :model do
end
