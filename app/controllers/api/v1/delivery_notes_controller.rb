module Api
  module V1
    class DeliveryNotesController < ApplicationController
      def index
        service = Firebird::DeliveryNoteService.new
        delivery_notes = service.all
        
        render json: {
          success: true,
          data: delivery_notes.map(&:as_json)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :internal_server_error
      end

      def show
        service = Firebird::DeliveryNoteService.new
        
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
              error: 'Delivery note not found'
            }, status: :not_found
          end
        else
          delivery_note = service.find(params[:id])
          if delivery_note
            render json: {
              success: true,
              data: delivery_note.as_json
            }
          else
            render json: {
              success: false,
              error: 'Delivery note not found'
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
        service = Firebird::DeliveryNoteService.new
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
        service = Firebird::DeliveryNoteService.new
        
        if service.update(params[:id], update_params)
          delivery_note = service.find(params[:id])
          render json: {
            success: true,
            data: delivery_note.as_json,
            message: 'Delivery note updated successfully'
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

      def update_item
        service = Firebird::DeliveryNoteService.new
        
        if service.update_item(params[:id], params[:item_id], item_update_params)
          items = service.get_items(params[:id])
          item = items.find { |i| i.posnr == params[:item_id].to_i }
          
          render json: {
            success: true,
            data: item.as_json,
            message: 'Delivery note item updated successfully'
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
        params.require(:delivery_note).permit(:lkwnr, :geplliefdatum)
      end

      def item_update_params
        params.require(:item).permit(:liefmenge)
      end
    end
  end
end
