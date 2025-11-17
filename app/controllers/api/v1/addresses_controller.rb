module Api
  module V1
    class AddressesController < ApplicationController
      def index
        service = Firebird::AddressService.new
        addresses = service.all
        
        render json: {
          success: true,
          data: addresses.map(&:as_json)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def show
        service = Firebird::AddressService.new
        address = service.find(params[:id])
        
        if address
          render json: {
            success: true,
            data: address.as_json
          }
        else
          render json: {
            success: false,
            error: 'Address not found'
          }, status: :not_found
        end
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def update
        service = Firebird::AddressService.new
        
        if service.update(params[:id], update_params)
          address = service.find(params[:id])
          render json: {
            success: true,
            data: address.as_json,
            message: 'Address updated successfully'
          }
        else
          render json: {
            success: false,
            error: 'No valid attributes to update'
          }, status: :unprocessable_entity
        end
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      private

      def update_params
        params.require(:address).permit(
          :name1, :name2, :strasse, :plz, :ort, :land,
          :telefon1, :telefon2, :telefax, :email, :homepage,
          :anrede, :briefanr
        )
      end
    end
  end
end
