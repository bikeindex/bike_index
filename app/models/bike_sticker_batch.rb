# == Schema Information
#
# Table name: bike_sticker_batches
# Database name: primary
#
#  id                 :integer          not null, primary key
#  code_number_length :integer
#  notes              :text
#  prefix             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  organization_id    :integer
#  user_id            :integer
#
# Indexes
#
#  index_bike_sticker_batches_on_organization_id  (organization_id)
#  index_bike_sticker_batches_on_user_id          (user_id)
#
class BikeStickerBatch < ApplicationRecord
  belongs_to :user # Creator of the batch
  belongs_to :organization
  has_many :bike_stickers

  before_validation :set_calculated_attributes

  attr_accessor :initial_code_integer, :stickers_to_create_count

  def min_code_integer
    bike_stickers.minimum(:code_integer) || 0
  end

  def max_code_integer
    bike_stickers.maximum(:code_integer) || 0
  end

  # Should be called through CreateBikeStickerCodesJob generally
  def create_codes(number_to_create, initial_code_integer: nil, kind: "sticker")
    raise "Prefix required to create sequential codes!" unless prefix.present?

    initial_code_integer ||= max_code_integer
    initial_code_integer += 1 if bike_stickers.where(code_integer: initial_code_integer).present?
    number_to_create.times do |i|
      code_integer_with_padding = (i + initial_code_integer).to_s.rjust(code_number_length, "0")
      bike_stickers.create!(
        organization: organization,
        kind: kind,
        code: prefix + code_integer_with_padding
      )
    end
    touch # Bump
  end

  def calculated_code_number_length
    return code_number_length if code_number_length.present?

    to_create_count = stickers_to_create_count&.to_i || 0
    estimated_finish_integer = (initial_code_integer&.to_i || max_code_integer) + to_create_count
    estimated_code_length = estimated_finish_integer.to_s.length
    # minimum of 4. Return a larger number if there's a larger code in the batch
    (estimated_code_length > 4) ? estimated_code_length : 4
  end

  # Shouldn't occur anymore, but included for legacy diagnostic purposes
  def duplicated_integers
    bike_sticker_integers.map { |int|
      next unless bike_sticker_integers.count(int) > 1

      int
    }.reject(&:blank?)
  end

  # Really simple implementation for diagnostic purposes
  def non_sequential_integers
    non_sequential = []
    previous = nil
    bike_sticker_integers.uniq.sort.each do |i|
      # Only run this if previous is present
      if previous.present? && previous + 1 != i
        non_sequential << [previous, i]
      end
      previous = i
    end
    non_sequential
  end

  def set_calculated_attributes
    self.prefix = prefix&.upcase&.strip
    # Set this because we calculate off it in Admin controller
    self.initial_code_integer = initial_code_integer&.to_i
    self.code_number_length = calculated_code_number_length
  end

  private

  def bike_sticker_integers
    @bike_sticker_integers ||= bike_stickers.pluck(:code_integer)
  end
end
