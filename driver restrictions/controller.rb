# app/controllers/address_restrictions_controller.rb
class AddressRestrictionsController < ApplicationController
  before_action :set_driver, only: [ :index, :create ]

  def index
    @address_restrictions = @driver.address_restrictions.includes(:address)
    @available_addresses = Address.where.not(id: @driver.blocked_addresses.ids)
  end

  def create
    @restriction = @driver.address_restrictions.build(address_restriction_params)

    if @restriction.save
      redirect_to driver_address_restrictions_path(@driver), notice: "Adresse gesperrt."
    else
      redirect_to driver_address_restrictions_path(@driver), alert: "Fehler beim Sperren."
    end
  end

  def destroy
    @restriction = AddressRestriction.find(params[:id])
    @restriction.destroy
    redirect_to driver_address_restrictions_path(@restriction.driver), notice: "Sperre aufgehoben."
  end

  private

  def set_driver
    @driver = Driver.find(params[:driver_id])
  end

  def address_restriction_params
    params.require(:address_restriction).permit(:address_id, :reason)
  end
end
