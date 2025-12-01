class AddressRestrictionsController < ApplicationController
  before_action :set_address_restriction, only: [:destroy]

  def index
    @restrictions_by_driver = AddressRestriction.includes(:driver)
                                                .group_by(&:driver)
                                                .sort_by { |driver, _| driver.full_name }
  end

  def new
    @address_restriction = AddressRestriction.new
    @available_addresses = load_available_addresses
  end

  def create
    @address_restriction = AddressRestriction.new(restriction_params)

    respond_to do |format|
      if @address_restriction.save
        format.html { redirect_to address_restrictions_path, notice: "Einschränkung wurde eingetragen." }
        format.json { render :show, status: :created, location: @address_restriction }
      else
        @available_addresses = load_available_addresses
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
        format.html { redirect_to address_restrictions_path, notice: "Sperre wurde erfolgreich entfernt.", status: :see_other }
      else
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
    params.expect(address_restriction: [:driver_id, :liefadrnr, :reason])
  end

  def load_available_addresses
    UnassignedDeliveryItem
      .where.not(liefadrnr: nil)
      .select(:liefadrnr, :kundname, :liefname, :ladeort)
      .distinct
      .order(:kundname)
      .map { |item|
        parts = []
        parts << item.kundname if item.kundname.present?
        parts << item.liefname if item.liefname.present? && item.liefname != item.kundname
        parts << item.ladeort if item.ladeort.present?

        label = parts.any? ? parts.join(" - ") : "Adresse #{item.liefadrnr}"
        [label, item.liefadrnr]
      }
  end
end