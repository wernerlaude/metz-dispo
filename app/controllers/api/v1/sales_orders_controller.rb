module Api
  module V1
    class SalesOrdersController < ApplicationController
      def index
        service = Firebird::SalesOrderService.new
        sales_orders = service.all
        
        render json: {
          success: true,
          data: sales_orders.map(&:as_json)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def show
        service = Firebird::SalesOrderService.new
        
        if params[:with_items] == 'true'
          result = service.find_with_items(params[:id])
          if result
            render json: {
              success: true,
              data: result
            }
          else
            render json: {
              success: false,
              error: 'Sales order not found'
            }, status: :not_found
          end
        else
          sales_order = service.find(params[:id])
          if sales_order
            render json: {
              success: true,
              data: sales_order.as_json
            }
          else
            render json: {
              success: false,
              error: 'Sales order not found'
            }, status: :not_found
          end
        end
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def items
        service = Firebird::SalesOrderService.new
        items = service.get_items(params[:id])
        
        render json: {
          success: true,
          data: items.map(&:as_json)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def update
        service = Firebird::SalesOrderService.new
        
        if service.update(params[:id], update_params)
          sales_order = service.find(params[:id])
          render json: {
            success: true,
            data: sales_order.as_json,
            message: 'Sales order updated successfully'
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
        params.require(:sales_order).permit(
          :geplliefdatum, :liefertext, :objekt, :auftstatus
        )
      end
    end
  end
end
