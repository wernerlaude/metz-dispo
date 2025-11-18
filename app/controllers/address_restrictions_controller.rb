class AddressRestrictionsController < ApplicationController
  before_action :set_address_restriction, only: %i[ show edit update destroy ]

  # GET /address_restrictions or /address_restrictions.json
  def index
    @address_restrictions = AddressRestriction.all
  end

  # GET /address_restrictions/1 or /address_restrictions/1.json
  def show
  end

  # GET /address_restrictions/new
  def new
    @address_restriction = AddressRestriction.new
  end

  # GET /address_restrictions/1/edit
  def edit
  end

  # POST /address_restrictions or /address_restrictions.json
  def create
    @address_restriction = AddressRestriction.new(address_restriction_params)

    respond_to do |format|
      if @address_restriction.save
        format.html { redirect_to @address_restriction, notice: "Address restriction was successfully created." }
        format.json { render :show, status: :created, location: @address_restriction }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @address_restriction.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /address_restrictions/1 or /address_restrictions/1.json
  def update
    respond_to do |format|
      if @address_restriction.update(address_restriction_params)
        format.html { redirect_to @address_restriction, notice: "Address restriction was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @address_restriction }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @address_restriction.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /address_restrictions/1 or /address_restrictions/1.json
  def destroy
    @address_restriction.destroy!

    respond_to do |format|
      format.html { redirect_to address_restrictions_path, notice: "Address restriction was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_address_restriction
      @address_restriction = AddressRestriction.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def address_restriction_params
      params.expect(address_restriction: [ :driver_id, :adresses_id ])
    end
end
