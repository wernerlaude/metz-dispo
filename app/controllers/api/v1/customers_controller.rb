module Api
  module V1
    class CustomersController < ApplicationController
      def index
        service = Firebird::CustomerService.new
        customers = service.all
        
        render json: {
          success: true,
          data: customers.map(&:as_json)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def show
        service = Firebird::CustomerService.new
        customer = service.find(params[:id])
        
        if customer
          render json: {
            success: true,
            data: customer.as_json
          }
        else
          render json: {
            success: false,
            error: 'Customer not found'
          }, status: :not_found
        end
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def update
        service = Firebird::CustomerService.new
        
        if service.update(params[:id], update_params)
          customer = service.find(params[:id])
          render json: {
            success: true,
            data: customer.as_json,
            message: 'Customer updated successfully'
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
        params.require(:customer).permit(
          :kundgruppe, :rabatt, :zahlungart, :umsatzsteuer, :gekuendigt
        )
      end
    end
  end
end
