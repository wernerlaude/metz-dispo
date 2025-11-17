Rails.application.routes.draw do
  root "tours#index"
  get "tours", to: "tours#index"

  resources :tours do
    member do
      patch :update_driver
      patch :update_location
      patch :assign_positions  # NEU: Für das Hinzufügen von Positionen
      get :delivery_positions
      get :details
      patch :update_sequence
      get :export_pdf
    end
    collection do
      post :refresh_unassigned
    end
  end

  namespace :api do
    namespace :v1 do
      # Addresses
      resources :addresses, only: [:index, :show, :update]

      # Customers
      resources :customers, only: [:index, :show, :update]

      # Sales Orders
      resources :sales_orders, only: [:index, :show, :update] do
        member do
          get :items
        end
      end

      # Delivery Notes
      resources :delivery_notes, only: [:index, :show, :update] do
        member do
          get :items
          patch 'items/:item_id', action: :update_item, as: :update_item
        end
      end
    end
  end

  resources :delivery_positions do
    member do
      patch :assign
      patch :unassign
      patch :move_up
      patch :move_down
      get :details
    end

    collection do
      patch :assign_multiple     # Batch assignment
      patch :reorder_in_tour     # NEW: Drag & drop reordering
      get :unassigned
    end
  end
  resources :unassigned_delivery_items, only: [ :show, :update ]

  get "up" => "rails/health#show", as: :rails_health_check
end