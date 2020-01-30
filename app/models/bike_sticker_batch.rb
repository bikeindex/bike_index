class BikeStickerBatch < ApplicationRecord
  belongs_to :user # Creator of the batch
  belongs_to :organization
  has_many :bike_stickers

  def min_code_integer; bike_stickers.minimum(:code_integer) || 0 end

  def max_code_integer; bike_stickers.maximum(:code_integer) || 0 end

  def create_codes(number_to_create, initial_code_integer: nil, kind: "sticker")
    raise "Prefix required to create sequential codes!" unless prefix.present?
    initial_code_integer ||= max_code_integer
    initial_code_integer += 1 if bike_stickers.where(code_integer: initial_code_integer).present?
    clength = code_number_length_or_default # Assign so it isn't recalculated in loop
    number_to_create.times do |i|
      code_integer_with_padding = (i + initial_code_integer).to_s.rjust(clength, "0")
      bike_stickers.create!(
        organization: organization,
        kind: kind,
        code: prefix + code_integer_with_padding,
      )
    end
    touch # Bump
  end

  def code_number_length_or_default
    return code_number_length if code_number_length.present?
    # minimum of 4. Return a larger number if there's a larger code in the batch
    max_code_integer.to_s.length > 4 ? max_code_integer.to_s.length : 4
  end

  # Shouldn't occur anymore, but included for legacy diagnostic purposes
  def duplicated_integers
    bike_sticker_integers.map do |int|
      next unless bike_sticker_integers.count(int) > 1
      int
    end.reject(&:blank?)
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

  private

  def bike_sticker_integers
    @bike_sticker_integers ||= bike_stickers.pluck(:code_integer)
  end
end
