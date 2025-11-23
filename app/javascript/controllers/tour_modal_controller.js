// app/javascript/controllers/tour_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { tourId: String }

    connect() {
        console.log('Tour Modal Controller connected')
    }

    async showTourModal(event) {
        try {
            // Tour-ID aus dem Button holen
            const button = event.currentTarget
            const tourId = button.getAttribute('data-tour-id') ||
                button.dataset.tourId ||
                this.tourIdValue

            if (!tourId) {
                console.error('No tour ID found!')
                alert('Fehler: Keine Tour-ID gefunden')
                return
            }

            this.tourIdValue = tourId
            console.log('Opening tour modal for:', tourId)

            await this.loadRequiredAssets()
            await this.showModal()
        } catch (error) {
            console.error('Error in showTourModal:', error)
            alert(`Fehler beim Öffnen: ${error.message}`)
        }
    }

    async loadRequiredAssets() {
        const promises = []

        // Leaflet CSS
        if (!document.querySelector('link[href*="leaflet"]')) {
            const css = document.createElement('link')
            css.rel = 'stylesheet'
            css.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
            document.head.appendChild(css)
        }

        // Leaflet JS
        if (!window.L) {
            promises.push(this.loadLeaflet())
        }

        // Sortable JS
        if (!window.Sortable) {
            promises.push(this.loadSortable())
        }

        await Promise.all(promises)
    }

    loadLeaflet() {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script')
            script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
            script.onload = resolve
            script.onerror = reject
            document.head.appendChild(script)
        })
    }

    loadSortable() {
        return new Promise((resolve) => {
            const script = document.createElement('script')
            script.src = 'https://cdn.jsdelivr.net/npm/sortablejs@latest/Sortable.min.js'
            script.onload = resolve
            script.onerror = resolve
            document.head.appendChild(script)
        })
    }

    async showModal() {
        try {
            const url = `/tours/${this.tourIdValue}/details`
            console.log('Fetching from:', url)

            const response = await fetch(url, {
                headers: {
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                }
            })

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`)
            }

            const data = await response.json()
            await this.createModal(data)

        } catch (error) {
            console.error('Error loading tour data:', error)
            alert('Fehler beim Laden der Tour-Daten')
        }
    }

    async createModal(tourData) {
        const existingModal = document.querySelector('.tour-detail-modal')
        if (existingModal) existingModal.remove()

        const modal = document.createElement('div')
        modal.className = 'tour-detail-modal'
        modal.innerHTML = this.buildModalContent(tourData)
        document.body.appendChild(modal)

        this.attachModalEventListeners(modal)

        requestAnimationFrame(async () => {
            modal.classList.add('show')
            await new Promise(resolve => setTimeout(resolve, 100))
            this.initializeMap()
            this.initializeSortable()

            if (tourData.deliveries?.length > 0) {
                await this.processGeocoding(tourData)
            }

            this.originalData = tourData
        })
    }

    buildModalContent(data) {
        const deliveries = data.deliveries || []
        const driverName = data.driver?.name || 'Nicht zugewiesen'
        const vehicleName = data.vehicle?.name || 'Nicht zugewiesen'
        const tourName = data.name || data.id
        const tourDate = data.date || ''

        const deliveriesHTML = deliveries.length > 0
            ? deliveries.map((delivery, index) => {
                const addr = delivery.delivery_address || {}
                return `
                    <div class="tour-detail-delivery-item" data-delivery-id="${delivery.id}" data-sequence="${index + 1}">
                        <div class="tour-detail-delivery-handle">⋮⋮</div>
                        <div class="tour-detail-delivery-content">
                            <div class="tour-detail-delivery-main">
                                <span class="tour-detail-sequence-number">${index + 1}</span>
                                <div class="tour-detail-delivery-details">
                                    <div class="tour-detail-delivery-title">${addr.name1 || 'Unbekannt'}</div>
                                    <div class="tour-detail-delivery-address">
                                        ${addr.strasse || ''}<br>
                                        ${addr.plz || ''} ${addr.ort || ''}
                                    </div>
                                </div>
                            </div>
                            <div class="tour-detail-delivery-meta">
                                <span class="delivery-products">${delivery.positions?.length || 0} Artikel</span>
                            </div>
                        </div>
                    </div>
                `
            }).join('')
            : '<div class="tour-detail-no-deliveries">Keine Lieferungen gefunden</div>'

        return `
            <div class="tour-detail-content" data-modal-content>
                <div class="tour-detail-header">
                    <h3>Tour ${tourName} - ${tourDate}</h3>
                    <button type="button" class="tour-detail-close" title="Schließen">&times;</button>
                </div>
                
                <div class="tour-detail-body">
                    <div class="tour-detail-container">
                        <div class="tour-detail-deliveries">
                            <div class="tour-detail-delivery-header">
                                <h4>Lieferungen</h4>
                                <div class="tour-detail-info">
                                    <span>Fahrer: ${driverName}</span>
                                    <span>Fahrzeug: ${vehicleName}</span>
                                </div>
                            </div>
                            
                            <div id="tour-delivery-list" class="tour-detail-delivery-list">
                                ${deliveriesHTML}
                            </div>
                            
                            <div class="tour-detail-summary">
                                <div class="tour-detail-summary-item">
                                    <span class="label">Gesamtentfernung:</span>
                                    <span>Wird berechnet...</span>
                                </div>
                                <div class="tour-detail-summary-item">
                                    <span class="label">Geschätzte Zeit:</span>
                                    <span>Wird berechnet...</span>
                                </div>
                                <div class="tour-detail-summary-item">
                                    <span class="label">Lieferungen:</span>
                                    <span>${deliveries.length}</span>
                                </div>
                            </div>
                        </div>

                        <div class="tour-detail-map-container">
                            <div id="tour-detail-map" class="tour-detail-map"></div>
                        </div>
                    </div>
                </div>
                
                <div class="tour-detail-actions">
                    <button type="button" class="btn btn-cancel">Abbrechen</button>
                    <a href="/tours/${data.id}/export_pdf" target="_blank" class="btn btn--secondary">
                        📄 PDF Export
                    </a>
                    <button type="button" class="btn btn-primary">
                        💾 Reihenfolge Speichern
                    </button>
                </div>
            </div>
        `
    }

    attachModalEventListeners(modal) {
        const closeBtn = modal.querySelector('.tour-detail-close')
        if (closeBtn) {
            closeBtn.addEventListener('click', (e) => {
                e.preventDefault()
                this.closeModal()
            })
        }

        const cancelBtn = modal.querySelector('.btn-cancel')
        if (cancelBtn) {
            cancelBtn.addEventListener('click', (e) => {
                e.preventDefault()
                this.closeModal()
            })
        }

        const saveBtn = modal.querySelector('.btn-primary')
        if (saveBtn) {
            saveBtn.addEventListener('click', (e) => {
                e.preventDefault()
                this.saveTourOrder()
            })
        }

        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                this.closeModal()
            }
        })

        this.escapeHandler = (e) => {
            if (e.key === 'Escape') {
                this.closeModal()
            }
        }
        document.addEventListener('keydown', this.escapeHandler)
    }

    initializeSortable() {
        const deliveryList = document.getElementById('tour-delivery-list')
        if (!deliveryList || !window.Sortable) return

        this.sortable = window.Sortable.create(deliveryList, {
            handle: '.tour-detail-delivery-handle',
            animation: 150,
            ghostClass: 'sortable-ghost',
            chosenClass: 'sortable-chosen',
            onEnd: (evt) => {
                this.updateSequenceNumbers()
                this.updateMapMarkers()
                setTimeout(() => this.updateRouteFromCurrentOrder(), 100)
            }
        })
    }

    initializeMap() {
        if (!window.L) return

        try {
            this.map = L.map('tour-detail-map').setView([51.1657, 10.4515], 6)

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap'
            }).addTo(this.map)

            this.markers = []
            this.routeLayer = null
        } catch (error) {
            console.error('Map init error:', error)
        }
    }

    async processGeocoding(tourData) {
        const deliveries = tourData.deliveries || []

        for (let i = 0; i < deliveries.length; i++) {
            const delivery = deliveries[i]
            const address = delivery.delivery_address

            if (!address) continue

            if (!address.lat || !address.lng) {
                const result = await this.geocodeAddress(address)
                if (result) {
                    address.lat = result.lat
                    address.lng = result.lng
                } else {
                    address.lat = 48.5 + Math.random() * 2
                    address.lng = 9.5 + Math.random() * 3
                }
            }

            this.addSingleMarker(address, i + 1, delivery)

            if (i < deliveries.length - 1) {
                await new Promise(resolve => setTimeout(resolve, 1100))
            }
        }

        this.fitMapToMarkers()
        this.updateSequenceNumbers()
        setTimeout(() => this.updateRouteFromCurrentOrder(), 300)
    }

    async geocodeAddress(address) {
        try {
            const query = `${address.strasse}, ${address.plz} ${address.ort}, Deutschland`
            const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(query)}&format=json&limit=1&countrycodes=de`

            const response = await fetch(url)
            if (!response.ok) return null

            const data = await response.json()
            if (data && data.length > 0) {
                return {
                    lat: parseFloat(data[0].lat),
                    lng: parseFloat(data[0].lon)
                }
            }
            return null
        } catch (error) {
            console.error('Geocoding error:', error)
            return null
        }
    }

    addSingleMarker(address, number, delivery) {
        if (!this.map || !address.lat || !address.lng) return

        const marker = L.marker([address.lat, address.lng], {
            icon: L.divIcon({
                className: 'custom-marker',
                html: `<div class="marker-number">${number}</div>`,
                iconSize: [30, 30]
            })
        }).addTo(this.map)

        marker.bindPopup(`
            <strong>${address.name1 || 'Unbekannt'}</strong><br>
            ${address.strasse || ''}<br>
            ${address.plz || ''} ${address.ort || ''}
        `)

        this.markers.push({ marker, address, number, delivery })
    }

    fitMapToMarkers() {
        if (!this.map || !this.markers || this.markers.length === 0) return

        const group = L.featureGroup(this.markers.map(m => m.marker))
        this.map.fitBounds(group.getBounds().pad(0.1))
    }

    updateSequenceNumbers() {
        const items = document.querySelectorAll('.tour-detail-delivery-item')
        items.forEach((item, index) => {
            const numberEl = item.querySelector('.tour-detail-sequence-number')
            if (numberEl) {
                numberEl.textContent = index + 1
            }
        })
    }

    updateMapMarkers() {
        if (!this.map || !this.markers) return

        const items = document.querySelectorAll('.tour-detail-delivery-item')
        items.forEach((item, index) => {
            const deliveryId = item.dataset.deliveryId
            const markerData = this.markers.find(m => m.delivery?.id == deliveryId)

            if (markerData) {
                const icon = L.divIcon({
                    className: 'custom-marker',
                    html: `<div class="marker-number">${index + 1}</div>`,
                    iconSize: [30, 30]
                })
                markerData.marker.setIcon(icon)
            }
        })
    }

    updateRouteFromCurrentOrder() {
        if (this.routeLayer) {
            this.map.removeLayer(this.routeLayer)
        }

        const items = document.querySelectorAll('.tour-detail-delivery-item')
        const coordinates = []

        items.forEach(item => {
            const deliveryId = item.dataset.deliveryId
            const delivery = this.originalData?.deliveries?.find(d => d.id == deliveryId)

            if (delivery?.delivery_address?.lat && delivery?.delivery_address?.lng) {
                coordinates.push([delivery.delivery_address.lat, delivery.delivery_address.lng])
            }
        })

        if (coordinates.length >= 2) {
            this.drawSimpleRoute(coordinates)
        }
    }

    drawSimpleRoute(coordinates) {
        if (coordinates.length < 2) return

        this.routeLayer = L.polyline(coordinates, {
            color: '#007bff',
            weight: 3,
            opacity: 0.7
        }).addTo(this.map)

        let totalDistance = 0
        for (let i = 1; i < coordinates.length; i++) {
            const from = L.latLng(coordinates[i-1])
            const to = L.latLng(coordinates[i])
            totalDistance += from.distanceTo(to)
        }

        const totalKm = (totalDistance / 1000).toFixed(1)
        const estimatedTime = Math.round(totalDistance / 1000 * 1.5)

        const distanceEl = document.querySelector('.tour-detail-summary-item:nth-child(1) span:last-child')
        const timeEl = document.querySelector('.tour-detail-summary-item:nth-child(2) span:last-child')

        if (distanceEl) distanceEl.textContent = `${totalKm} km`
        if (timeEl) timeEl.textContent = `ca. ${estimatedTime} min`
    }

    async saveTourOrder() {
        const items = document.querySelectorAll('.tour-detail-delivery-item')
        const newOrder = Array.from(items).map((item, index) => ({
            position_id: item.dataset.deliveryId,
            sequence_number: index + 1
        }))

        try {
            const response = await fetch(`/tours/${this.tourIdValue}/update_sequence`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                },
                body: JSON.stringify({ positions: newOrder })
            })

            if (response.ok) {
                this.showSuccessMessage()

                // Tour-Card entfernen
                this.removeTourCard()

                setTimeout(() => {
                    this.closeModal()
                    window.location.reload()
                }, 1500)
            } else {
                alert('Fehler beim Speichern')
            }
        } catch (error) {
            console.error('Save error:', error)
            alert('Fehler beim Speichern')
        }
    }

    removeTourCard() {
        const tourCard = document.querySelector(`.tour-card[data-tour-id="${this.tourIdValue}"]`)

        if (tourCard) {
            console.log("✓ Removing tour card:", this.tourIdValue)
            tourCard.style.transition = 'all 0.3s ease'
            tourCard.style.opacity = '0'
            tourCard.style.transform = 'scale(0.95)'
            setTimeout(() => tourCard.remove(), 300)
        }
    }

    showSuccessMessage() {
        const successEl = document.createElement('div')
        successEl.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #28a745;
            color: white;
            padding: 1rem 2rem;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            z-index: 10000;
        `
        successEl.textContent = 'Tour-Reihenfolge erfolgreich gespeichert!'
        document.body.appendChild(successEl)

        setTimeout(() => {
            successEl.style.opacity = '0'
            successEl.style.transition = 'opacity 0.3s'
            setTimeout(() => successEl.remove(), 300)
        }, 2000)
    }

    closeModal() {
        const modal = document.querySelector('.tour-detail-modal')
        if (modal) {
            modal.classList.remove('show')

            if (this.escapeHandler) {
                document.removeEventListener('keydown', this.escapeHandler)
                this.escapeHandler = null
            }

            setTimeout(() => {
                modal.remove()
                if (this.map) {
                    this.map.remove()
                    this.map = null
                }
                this.markers = []
                this.routeLayer = null
            }, 300)
        }
    }
}