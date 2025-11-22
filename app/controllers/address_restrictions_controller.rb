class AddressRestrictionsController < ApplicationController
  before_action :set_address_restriction, only: [ :destroy ]

  def index
    # Lade Driver UND LoadingLocation eager
    @restrictions_by_driver = AddressRestriction.includes(:driver, :loading_location)
                                                .group_by(&:driver)
                                                .sort_by { |driver, _| driver.full_name }
  end

  def new
    @address_restriction = AddressRestriction.new
  end

  # GET /trailers/1/edit
  def edit
  end

  # POST /trailers or /trailers.json
  def create
    @address_restriction = AddressRestriction.new(restriction_params)

    respond_to do |format|
      if @address_restriction.save
        format.html { redirect_to address_restrictions_path, notice: "Einschränkung wurde eingetragen." }
        format.json { render :show, status: :created, location: @address_restriction }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @address_restriction.errors, status: :unprocessable_entity }
      end
    end
  end


  def destroy
    driver = @address_restriction.driver
    @address_restriction.destroy!

    respond_to do |format|
      if request.referer&.include?("address_restrictions")
        # Wenn von der Index-Seite, bleibe dort
        format.html { redirect_to address_restrictions_path, notice: "Sperre wurde erfolgreich entfernt.", status: :see_other }
      else
        # Sonst zurück zum Driver
        format.html { redirect_to driver_path(driver), notice: "Sperre wurde erfolgreich entfernt.", status: :see_other }
      end
      format.json { head :no_content }
    end
  end

  private

  def set_address_restriction
    @address_restriction = AddressRestriction.find(params[:id])
  end
  def restriction_params
    params.expect(address_restriction: [ :driver_id, :liefadrnr, :reason ])
  end
end
