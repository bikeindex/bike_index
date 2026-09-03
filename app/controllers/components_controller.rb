class ComponentsController < ApplicationController
  def index
    @ctypes = Ctype.includes(:cgroup).order(:name)

    respond_to do |format|
      format.csv { render plain: Spreadsheets::Components.to_csv(@ctypes) }
    end
  end
end
