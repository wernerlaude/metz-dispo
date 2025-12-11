// app/javascript/controllers/tour_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { tourId: String }

    connect() {
        console.log('Tour Modal Controller connected')
        this.geocodeCache = new Map()
    }

    async showTourModal(event) {
        try {
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

        if (!document.querySelector('link[href*="leaflet"]')) {
            const css = document.createElement('link')
            css.rel = 'stylesheet'
            css.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
            document.head.appendChild(css)
        }

        if (!window.L) {
            promises.push(this.loadLeaflet())
        }

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
            console.log('Tour data received:', data)
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

            this.originalData = tourData  // ← VORHER setzen!

            await this.processAllGeocoding(tourData)
        })
    }

    buildModalContent(data) {
        const deliveries = data.deliveries || []
        const driverName = data.driver?.name || 'Nicht zugewiesen'
        const vehicleName = data.vehicle?.name || 'Nicht zugewiesen'
        const trailerName = data.trailer?.name || 'Kein Hänger'
        const loadingLocationId = data.loading_location?.id || ''
        const totalWeight = data.total_weight || 0
        const tourName = data.name || data.id
        const tourDate = data.date || ''

        const loadingLocations = data.loading_locations || []
        const loadingLocationOptions = loadingLocations.map(loc =>
            `<option value="${loc.id}" ${loc.id === loadingLocationId ? 'selected' : ''}>${loc.name}</option>`
        ).join('')

        const deliveriesHTML = deliveries.length > 0
            ? deliveries.map((delivery, index) => {
                const addr = delivery.delivery_address || {}
                const kessel = delivery.kessel || ''
                const weight = delivery.weight || 0

                // Kessel formatieren: "1,2" → "K1, K2"
                const kesselFormatted = kessel
                    ? kessel.split(',').map(k => `K${k.trim()}`).join(', ')
                    : ''
                const kesselHTML = kesselFormatted
                    ? `<span class="delivery-kessel" title="Kessel">${kesselFormatted}</span>`
                    : ''

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
                                ${kesselHTML}
                                <span class="delivery-weight">${Math.round(weight)} kg</span>
                                <button type="button" 
                                        class="btn btn-print-label" 
                                        title="Bestellung drucken"
                                        data-position-id="${delivery.id}">
                                    🖨️
                                </button>
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
                                    <span>👤 ${driverName}</span>
                                    <span>🚛 ${vehicleName}</span>
                                    <span>➕ ${trailerName}</span>
                                    <span>⚖️ ${totalWeight} kg</span>
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
                            
                            <div class="tour-detail-loading-location">
                                <label for="loading-location-select">🏭 Ladeort:</label>
                                <select id="loading-location-select" class="form-control">
                                    <option value="">Ladeort wählen...</option>
                                    ${loadingLocationOptions}
                                </select>
                            </div>
                        </div>

                        <div class="tour-detail-map-container">
                            <div id="tour-detail-map" class="tour-detail-map"></div>
                        </div>
                    </div>
                </div>
                
                <div class="tour-detail-actions">
                    <button type="button" class="btn btn-cancel">Abbrechen</button>
                    <button type="button" class="btn btn-secondary btn-pdf-buero" data-tour-id="${data.id}">
                        📄 PDF Büro
                    </button>
                    <button type="button" class="btn btn-secondary btn-pdf-fahrer" data-tour-id="${data.id}">
                        📄 PDF Fahrer
                    </button>
                    <button type="button" class="btn btn--primary">
                        💾 Speichern
                    </button>
                </div>
            </div>
        `
    }

    attachModalEventListeners(modal) {
        const closeBtn = modal.querySelector('.tour-detail-close')
        const cancelBtn = modal.querySelector('.btn-cancel')
        const saveBtn = modal.querySelector('.btn--primary')

        closeBtn?.addEventListener('click', () => this.closeModal())
        cancelBtn?.addEventListener('click', () => this.closeModal())
        saveBtn?.addEventListener('click', () => this.saveTourOrder())

        modal.addEventListener('click', (e) => {
            if (e.target === modal || e.target.classList.contains('tour-detail-modal')) {
                this.closeModal()
            }
        })

        // PDF Büro Button
        modal.querySelector('.btn-pdf-buero')?.addEventListener('click', () => {
            const url = this.buildPdfUrl(`/tours/${this.tourIdValue}/export_pdf`)
            window.open(url, '_blank')
        })

        // PDF Fahrer Button
        modal.querySelector('.btn-pdf-fahrer')?.addEventListener('click', () => {
            const url = this.buildPdfUrl(`/tours/${this.tourIdValue}/export_pdf_driver`)
            window.open(url, '_blank')
        })

        // Print-Bestellung Buttons
        modal.querySelectorAll('.btn-print-label').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation()
                const positionId = btn.dataset.positionId
                const url = this.buildPdfUrl(`/unassigned_delivery_items/${positionId}/print_bestellung`)
                window.open(url, '_blank')
            })
        })

        this.escapeHandler = (e) => {
            if (e.key === 'Escape') this.closeModal()
        }
        document.addEventListener('keydown', this.escapeHandler)
    }

    // Helper: PDF URL mit Ladeort-Parameter bauen
    buildPdfUrl(baseUrl) {
        const loadingLocationSelect = document.getElementById('loading-location-select')
        const loadingLocationId = loadingLocationSelect?.value || ''
        const loadingLocationName = loadingLocationSelect?.options[loadingLocationSelect.selectedIndex]?.text || ''

        if (loadingLocationId && loadingLocationName !== 'Ladeort wählen...') {
            return `${baseUrl}?loading_location_id=${loadingLocationId}&loading_location_name=${encodeURIComponent(loadingLocationName)}`
        }
        return baseUrl
    }

    initializeMap() {
        const mapEl = document.getElementById('tour-detail-map')
        if (!mapEl || !window.L) return

        try {
            this.map = L.map('tour-detail-map').setView([49.4, 11.0], 8)
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap'
            }).addTo(this.map)
            this.markers = []
        } catch (error) {
            console.error('Map init error:', error)
        }
    }

    initializeSortable() {
        const list = document.getElementById('tour-delivery-list')
        if (!list || !window.Sortable) return

        new Sortable(list, {
            handle: '.tour-detail-delivery-handle',
            animation: 150,
            onEnd: async () => {
                this.updateSequenceNumbers()
                this.updateMapMarkers()
                this.updateRouteFromCurrentOrder()

                await this.saveSequenceQuietly()
            }
        })
    }

    async saveSequenceQuietly() {
        const items = document.querySelectorAll('.tour-detail-delivery-item')
        const newOrder = Array.from(items).map((item, index) => ({
            position_id: item.dataset.deliveryId,
            sequence_number: index + 1
        }))

        try {
            await fetch(`/tours/${this.tourIdValue}/update_sequence`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                },
                body: JSON.stringify({ positions: newOrder })
            })
        } catch (error) {
            console.error('Quiet save error:', error)
        }
    }

    async processAllGeocoding(tourData) {
        const deliveries = tourData.deliveries || []

        // Nur Lieferadressen geocoden (kein Ladeort)
        for (let i = 0; i < deliveries.length; i++) {
            const delivery = deliveries[i]
            const addr = delivery.delivery_address

            if (addr?.lat && addr?.lng) {
                this.addDeliveryMarker(delivery, i + 1, addr.lat, addr.lng)
            } else if (addr) {
                const addressStr = `${addr.strasse || ''}, ${addr.plz || ''} ${addr.ort || ''}`
                try {
                    const coords = await this.geocodeAddress(addressStr)
                    if (coords) {
                        delivery.delivery_address.lat = coords.lat
                        delivery.delivery_address.lng = coords.lng
                        this.addDeliveryMarker(delivery, i + 1, coords.lat, coords.lng)
                    }
                } catch (error) {
                    console.error(`Geocode error for delivery ${i + 1}:`, error)
                }
            }
        }

        this.fitMapToBounds()
        this.updateRouteFromCurrentOrder()
    }

    async geocodeAddress(address) {
        if (!address) return null

        // 1. Lokaler Memory-Cache
        if (this.geocodeCache.has(address)) {
            return this.geocodeCache.get(address)
        }

        // Adresse bereinigen für bessere Treffer
        const cleanAddress = this.cleanAddressForGeocoding(address)

        // 2. Backend-Cache prüfen
        try {
            const backendCoords = await this.lookupFromBackend(cleanAddress)
            if (backendCoords) {
                this.geocodeCache.set(address, backendCoords)
                return backendCoords
            }
        } catch (error) {
            console.warn('Backend lookup failed:', error)
        }

        // 3. Nominatim anfragen
        try {
            const response = await fetch(
                `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(cleanAddress)}&limit=1&countrycodes=de`,
                { headers: { 'User-Agent': 'MetzDispo/1.0' } }
            )
            const data = await response.json()

            if (data && data.length > 0) {
                const coords = { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
                this.geocodeCache.set(address, coords)

                // 4. Im Backend speichern für nächstes Mal
                this.saveToBackend(cleanAddress, coords)

                return coords
            } else {
                // Nicht gefunden - auch im Backend speichern (um erneute Anfragen zu vermeiden)
                this.saveToBackend(cleanAddress, null)
            }
        } catch (error) {
            console.error('Geocode error:', error)
        }

        return null
    }

    cleanAddressForGeocoding(address) {
        if (!address) return ''

        return address
            .replace(/,?\s*OT\s+[^,]+/gi, '')  // ", OT Bühl" oder "OT Großenried" entfernen (mit Umlauten)
            .replace(/\s*-\s*OT\s+[^,]+/gi, '') // "- OT Riesbürg" entfernen
            .replace(/\s+/g, ' ')               // Mehrfache Leerzeichen
            .replace(/^,\s*/, '')               // Führendes Komma entfernen
            .replace(/,\s*,/g, ',')             // Doppelte Kommas entfernen
            .trim()
    }

    async lookupFromBackend(address) {
        try {
            const response = await fetch(
                `/geocode_caches/lookup?address_string=${encodeURIComponent(address)}`,
                { headers: { 'Accept': 'application/json' } }
            )

            if (response.ok) {
                const data = await response.json()
                if (data.found) {
                    console.log('📍 Geocode from backend cache:', address)
                    return { lat: data.lat, lng: data.lng }
                }
            }
        } catch (error) {
            console.warn('Backend lookup error:', error)
        }
        return null
    }

    async saveToBackend(address, coords) {
        try {
            await fetch('/geocode_caches', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                },
                body: JSON.stringify({
                    address_string: address,
                    lat: coords?.lat || null,
                    lng: coords?.lng || null
                })
            })
            console.log('💾 Geocode saved to backend:', address)
        } catch (error) {
            console.warn('Backend save error:', error)
        }
    }

    addDeliveryMarker(delivery, index, lat, lng) {
        if (!this.map) return

        const icon = L.divIcon({
            className: 'custom-marker',
            html: `<div class="marker-number">${index}</div>`,
            iconSize: [30, 30]
        })

        const addr = delivery.delivery_address || {}
        const marker = L.marker([lat, lng], { icon })
            .addTo(this.map)
            .bindPopup(`
                <strong>${index}. ${addr.name1 || 'Unbekannt'}</strong><br>
                ${addr.strasse || ''}<br>
                ${addr.plz || ''} ${addr.ort || ''}
            `)

        this.markers.push({ marker, delivery })
    }

    fitMapToBounds() {
        if (!this.map || this.markers.length === 0) return

        const bounds = L.latLngBounds([])

        this.markers.forEach(({ marker }) => {
            bounds.extend(marker.getLatLng())
        })

        if (bounds.isValid()) {
            this.map.fitBounds(bounds, { padding: [30, 30] })
        }
    }

    updateSequenceNumbers() {
        const items = document.querySelectorAll('.tour-detail-delivery-item')
        items.forEach((item, index) => {
            const numberEl = item.querySelector('.tour-detail-sequence-number')
            if (numberEl) numberEl.textContent = index + 1
        })
    }

    updateMapMarkers() {
        if (!this.map) return

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

        const coordinates = []

        // Nur Lieferadressen in Route (kein Ladeort)
        const items = document.querySelectorAll('.tour-detail-delivery-item')
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
            const from = L.latLng(coordinates[i - 1])
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
            await this.saveLoadingLocation()

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
                await this.markTourAsCompleted()

                this.showSuccessMessage()

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

    async saveLoadingLocation() {
        const select = document.getElementById('loading-location-select')
        if (!select) return

        const loadingLocationId = select.value
        if (!loadingLocationId) return

        try {
            const response = await fetch(`/tours/${this.tourIdValue}`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                },
                body: JSON.stringify({ tour: { loading_location_id: loadingLocationId } })
            })

            if (response.ok) {
                console.log('✓ Loading location saved')
            }
        } catch (error) {
            console.error('Error saving loading location:', error)
        }
    }

    async markTourAsCompleted() {
        try {
            const response = await fetch(`/tours/${this.tourIdValue}/toggle_completed`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                }
            })

            if (response.ok) {
                console.log('✓ Tour marked as completed')
            }
        } catch (error) {
            console.error('Error marking tour as completed:', error)
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