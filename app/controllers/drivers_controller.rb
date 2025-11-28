class DriversController < ApplicationController
  before_action :set_driver, only: %i[ show edit update destroy toggle_active ]

  # GET /drivers or /drivers.json
  def index
    #  @drivers = Driver.includes(:vehicle, :trailer).sortiert
    # Füge einfach .to_a hinzu:
    @drivers = Rails.cache.fetch("drivers_sorted", expires_in: 2.days) do
      Driver.includes([:vehicle, :trailer]).sortiert
    end

  end

  def toggle_active
    if @driver.update(active: !@driver.active)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  # GET /drivers/1 or /drivers/1.json
  def show
    @driver = Driver.includes(:vehicle, :trailer, :tours, :address_restrictions)
                    .find(params[:id])
  end

  # GET /drivers/new
  def new
    @driver = Driver.new
  end

  # GET /drivers/1/edit
  def edit
  end

  # POST /drivers or /drivers.json
  def create
    @driver = Driver.new(driver_params)

    respond_to do |format|
      if @driver.save
        format.html { redirect_to @driver, notice: "Driver was successfully created." }
        format.json { render :show, status: :created, location: @driver }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @driver.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /drivers/1 or /drivers/1.json
  def update
    respond_to do |format|
      if @driver.update(driver_params)
        format.html { redirect_to @driver, notice: "Driver was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @driver }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @driver.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /drivers/1 or /drivers/1.json
  def destroy
    @driver.destroy!

    respond_to do |format|
      format.html { redirect_to drivers_path, notice: "Driver was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_driver
      @driver = Driver.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def driver_params
      params.expect(driver: [ :first_name, :last_name, :pin, :vehicle_id, :trailer_id, :tablet_id, :active, :driver_type ])
    end
end
