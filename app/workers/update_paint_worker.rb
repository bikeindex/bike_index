class UpdatePaintWorker < ApplicationWorker
  def perform(paint_id)
    paint = Paint.find(paint_id)
    black_id = Color.find_by_name("Black").id
    if paint.reload.color_id.present?
      bikes = paint.bikes.where(primary_frame_color_id: black_id)
      bikes.each do |bike|
        next if bike.secondary_frame_color_id.present?
        next unless bike.primary_frame_color_id == black_id
        bike.primary_frame_color_id = paint.color_id
        bike.secondary_frame_color_id = paint.secondary_color_id
        bike.tertiary_frame_color_id = paint.tertiary_color_id
        bike.paint_name = paint.name
        bike.save
      end
    end
  end
end
