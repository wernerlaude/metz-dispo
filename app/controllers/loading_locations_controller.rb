class LoadingLocationsController < ApplicationController
  before_action :set_loading_location, only: %i[ show edit update destroy toggle_active ]

  def index
    @loading_locations = LoadingLocation.by_name.all
  end

  def show
    @loading_location = LoadingLocation.includes(:tours).find(params[:id])
  end

  def new
    @loading_location = LoadingLocation.new
  end

  def edit
  end

  def create
    @loading_location = LoadingLocation.new(loading_location_params)

    if @loading_location.save
      redirect_to @loading_location, notice: "Ladeadresse wurde erfolgreich angelegt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @loading_location.update(loading_location_params)
      if request.format.json?
        render json: @loading_location
      else
        redirect_to @loading_location, notice: "Ladeadresse wurde erfolgreich aktualisiert."
      end
    else
      if request.format.json?
        render json: @loading_location.errors, status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @loading_location.destroy!
    redirect_to loading_locations_path, notice: "Ladeadresse wurde erfolgreich gelöscht.", status: :see_other
  end

  def toggle_active
    if @loading_location.update(active: !@loading_location.active)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private
  def set_loading_location
    @loading_location = LoadingLocation.find(params[:id])
  end

  def loading_location_params
    params.expect(loading_location: [ :name, :address, :contact_person, :phone, :active ])
  end
end
