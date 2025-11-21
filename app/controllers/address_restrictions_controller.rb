class AddressRestrictionsController < ApplicationController
  before_action :set_address_restriction, only: [ :destroy ]

  def index
    # Gruppiere nach Driver und lade Driver-Daten eager
    @restrictions_by_driver = AddressRestriction.includes(:driver)
                                                .group_by(&:driver)
                                                .sort_by { |driver, _| driver.full_name }
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
end
