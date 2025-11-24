class VehiclesController < ApplicationController
  before_action :set_vehicle, only: %i[ show edit update destroy ]

  def index
    @vehicles = Vehicle.by_license_plate.all
  end

  def show
    @vehicle = Vehicle.includes(:drivers).find(params[:id])
  end

  def new
    @vehicle = Vehicle.new
  end

  def edit
  end

  def create
    @vehicle = Vehicle.new(vehicle_params)

    if @vehicle.save
      redirect_to @vehicle, notice: "Fahrzeug wurde erfolgreich angelegt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vehicle.update(vehicle_params)
      if request.format.json?
        render json: @vehicle
      else
        redirect_to @vehicle, notice: "Fahrzeug wurde erfolgreich aktualisiert."
      end
    else
      if request.format.json?
        render json: @vehicle.errors, status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @vehicle.destroy!
    redirect_to vehicles_path, notice: "Fahrzeug wurde erfolgreich gelöscht.", status: :see_other
  end

  private
  def set_vehicle
    @vehicle = Vehicle.find(params[:id])
  end

  def vehicle_params
    params.expect(vehicle: [ :license_plate, :vehicle_number, :vehicle_type, :vehicle_short ])
  end
end
