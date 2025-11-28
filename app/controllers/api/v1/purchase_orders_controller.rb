# app/controllers/api/v1/purchase_orders_controller.rb
module Api
  module V1
    class PurchaseOrdersController < ApplicationController
      def index
        service = Firebird::PurchaseOrderService.new
        purchase_orders = service.all

        render json: {
          success: true,
          data: purchase_orders.map(&:as_json)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def show
        service = Firebird::PurchaseOrderService.new

        if params[:with_items] == "true"
          result = service.find_with_items(params[:id])
          if result
            render json: {
              success: true,
              data: result
            }
          else
            render json: {
              success: false,
              error: "Purchase order not found"
            }, status: :not_found
          end
        else
          purchase_order = service.find(params[:id])
          if purchase_order
            render json: {
              success: true,
              data: purchase_order.as_json
            }
          else
            render json: {
              success: false,
              error: "Purchase order not found"
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
        service = Firebird::PurchaseOrderService.new
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

      def pending
        service = Firebird::PurchaseOrderService.new
        purchase_orders = service.pending

        render json: {
          success: true,
          data: purchase_orders.map(&:as_json)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def update
        service = Firebird::PurchaseOrderService.new

        if service.update(params[:id], update_params)
          purchase_order = service.find(params[:id])
          render json: {
            success: true,
            data: purchase_order.as_json,
            message: "Purchase order updated successfully"
          }
        else
          render json: {
            success: false,
            error: "No valid attributes to update"
          }, status: :unprocessable_entity
        end
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def update_item
        service = Firebird::PurchaseOrderService.new

        if service.update_item(params[:id], params[:item_id], item_update_params)
          items = service.get_items(params[:id])
          item = items.find { |i| i.posnr == params[:item_id].to_i }

          render json: {
            success: true,
            data: item.as_json,
            message: "Purchase order item updated successfully"
          }
        else
          render json: {
            success: false,
            error: "No valid attributes to update"
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
        params.require(:purchase_order).permit(
          :beststatus, :liefertag, :erledigt, :text1, :text2, :uhrzeit
        )
      end

      def item_update_params
        params.require(:item).permit(:menge, :status)
      end
    end
  end
end