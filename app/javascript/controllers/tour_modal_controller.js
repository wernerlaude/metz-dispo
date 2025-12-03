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

            // Ladeort und Lieferungen geocoden
            await this.processAllGeocoding(tourData)

            this.originalData = tourData
        })
    }

    buildModalContent(data) {
        const deliveries = data.deliveries || []
        const driverName = data.driver?.name || 'Nicht zugewiesen'
        const vehicleName = data.vehicle?.name || 'Nicht zugewiesen'
        const loadingLocationName = data.loading_location?.name || 'Nicht zugewiesen'
        const tourName = data.name || data.id
        const tourDate = data.date || ''

        const deliveriesHTML = deliveries.length > 0
            ? deliveries.map((delivery, index) => {
                const addr = delivery.delivery_address || {}
                const ladeort = delivery.ladeort || ''

                const ladeortHTML = ladeort
                    ? `<div class="tour-detail-delivery-ladeort"><small>📍 Ladeort: ${ladeort}</small></div>`
                    : ''

                return `
                    <div class="tour-detail-delivery-item" data-delivery-id="${delivery.id}" data-sequence="${index + 1}">
                        <div class="tour-detail-delivery-handle">⋮⋮</div>
                        <div class="tour-detail-delivery-content">
                            <div class="tour-detail-delivery-main">
                                <span class="tour-detail-sequence-number">${index + 1}</span>
                                <div class="tour-detail-delivery-details">
                                    <div class="tour-detail-delivery-title">${addr.name1 || 'Unbekannt'}</div>
                                    ${ladeortHTML}
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
                                    <span>🏭 Start: ${loadingLocationName}</span>
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
                        📄 PDF Büro
                    </a>
                    <a href="/tours/${data.id}/export_pdf_driver" target="_blank" class="btn btn--secondary">
                        📄 PDF Fahrer
                    </a>
                    <button type="button" class="btn btn-primary">
                        💾 Speichern
                    </button>
                </div>
            </div>
        `
    }

    attachModalEventListeners(modal) {
        const closeBtn = modal.querySelector('.tour-detail-close')
        const cancelBtn = modal.querySelector('.btn-cancel')
        const saveBtn = modal.querySelector('.btn-primary')

        closeBtn?.addEventListener('click', () => this.closeModal())
        cancelBtn?.addEventListener('click', () => this.closeModal())
        saveBtn?.addEventListener('click', () => this.saveTourOrder())

        modal.addEventListener('click', (e) => {
            if (e.target === modal || e.target.classList.contains('tour-detail-modal')) {
                this.closeModal()
            }
        })

        this.escapeHandler = (e) => {
            if (e.key === 'Escape') this.closeModal()
        }
        document.addEventListener('keydown', this.escapeHandler)
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
            this.loadingLocationMarker = null
            this.loadingLocationCoords = null
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
            console.log('✓ Reihenfolge automatisch gespeichert')
        } catch (error) {
            console.error('Auto-save error:', error)
        }
    }

    // Hauptmethode: Ladeort + Lieferungen geocoden
    async processAllGeocoding(tourData) {
        // 1. Ladeort geocoden (als erstes, ist der Startpunkt)
        if (tourData.loading_location) {
            console.log('Geocoding loading location:', tourData.loading_location.name)
            await this.geocodeLoadingLocation(tourData.loading_location)
        }

        // 2. Lieferungen geocoden
        if (tourData.deliveries?.length > 0) {
            await this.processDeliveriesGeocoding(tourData)
        }

        // 3. Karte anpassen und Route zeichnen
        this.fitMapToAllMarkers()
        this.drawFullRoute()
    }

    // Adresse parsen: "Hauptstraße 32, 91723 Dittenheim" → {strasse, plz, ort}
    parseAddress(address) {
        if (!address) return null

        // Pattern: "Straße Nr, PLZ Ort" oder "Straße Nr, PLZ, Ort"
        const match = address.match(/^(.+?),\s*(\d{5})\s+(.+)$/)

        if (match) {
            return {
                strasse: match[1].trim(),
                plz: match[2].trim(),
                ort: match[3].trim()
            }
        }

        // Fallback: Nur PLZ + Ort suchen
        const plzMatch = address.match(/(\d{5})\s+(.+)/)
        if (plzMatch) {
            return {
                plz: plzMatch[1].trim(),
                ort: plzMatch[2].trim()
            }
        }

        return null
    }

    // Ladeort geocoden und grünen Marker setzen
    async geocodeLoadingLocation(location) {
        if (!location) return

        let coords = null

        // Wenn Koordinaten schon vorhanden
        if (location.lat && location.lng) {
            coords = { lat: location.lat, lng: location.lng }
        } else if (location.address) {
            // Versuche die kombinierte Adresse zu parsen
            const parsed = this.parseAddress(location.address)

            if (parsed) {
                console.log(`  Parsed address:`, parsed)

                // 1. Strukturierte Suche
                coords = await this.tryGeocodeStructured(parsed)

                // 2. Fallback: PLZ + Ort
                if (!coords && parsed.plz) {
                    await new Promise(r => setTimeout(r, 1100))
                    coords = await this.tryGeocodePLZOnly(parsed.plz)
                }

                // 3. Fallback: Nur Ort
                if (!coords && parsed.ort) {
                    await new Promise(r => setTimeout(r, 1100))
                    coords = await this.tryGeocodeOrtOnly(parsed.ort)
                }
            }

            // 4. Letzter Fallback: Komplette Adresse als Query
            if (!coords) {
                await new Promise(r => setTimeout(r, 1100))
                console.log(`  Trying full address query: ${location.address}`)
                coords = await this.tryGeocode(location.address)
            }
        }

        if (coords) {
            this.loadingLocationCoords = coords
            this.addLoadingLocationMarker(coords, location.name, location.address)
            console.log(`  → Ladeort geocoded: ${coords.lat}, ${coords.lng}`)
        } else {
            console.warn('  → Ladeort konnte nicht geocoded werden')
        }
    }

    // Grüner Marker für Ladeort (Startpunkt)
    addLoadingLocationMarker(coords, name, address) {
        if (!this.map) return

        const marker = L.marker([coords.lat, coords.lng], {
            icon: L.divIcon({
                className: 'custom-marker start-marker',
                html: `<div class="marker-number marker-start">🏭</div>`,
                iconSize: [36, 36]
            })
        }).addTo(this.map)

        marker.bindPopup(`
            <strong>🏭 Ladeort / Start</strong><br>
            ${name || 'Unbekannt'}<br>
            <small>${address || ''}</small>
        `)

        this.loadingLocationMarker = marker
    }

    async processDeliveriesGeocoding(tourData) {
        const deliveries = tourData.deliveries || []
        console.log(`Starting geocoding for ${deliveries.length} deliveries`)

        for (let i = 0; i < deliveries.length; i++) {
            const delivery = deliveries[i]
            const addr = delivery.delivery_address

            console.log(`Geocoding ${i + 1}/${deliveries.length}:`, addr?.strasse, addr?.plz, addr?.ort)

            if (addr?.lat && addr?.lng) {
                console.log(`  → Already has coordinates`)
                this.addSingleMarker(addr, i + 1, delivery)
            } else if (addr?.ort) {
                try {
                    const cacheKey = `${addr.plz || ''}-${addr.ort}`
                    if (!this.geocodeCache.has(cacheKey)) {
                        await new Promise(r => setTimeout(r, 1100))
                    }

                    const coords = await this.geocodeAddress(addr)

                    if (coords) {
                        console.log(`  → Geocoded: ${coords.lat}, ${coords.lng}`)
                        addr.lat = coords.lat
                        addr.lng = coords.lng
                        this.addSingleMarker(addr, i + 1, delivery)
                    } else {
                        console.warn(`  → Geocoding failed`)
                    }
                } catch (error) {
                    console.warn('Geocoding failed for:', addr, error)
                }
            } else {
                console.warn(`  → No address data`)
            }
        }

        console.log(`Geocoding complete. ${this.markers.length} delivery markers added.`)
    }

    isPostfachAddress(strasse) {
        if (!strasse) return false
        const lower = strasse.toLowerCase()
        return lower.includes('postfach') ||
            lower.includes('p.o. box') ||
            lower.includes('pf ') ||
            lower.match(/^pf\d/) !== null
    }

    async geocodeAddress(addr) {
        const cacheKey = `${addr.plz || ''}-${addr.ort}`

        if (this.geocodeCache.has(cacheKey)) {
            console.log(`  → Aus Cache: ${cacheKey}`)
            return this.geocodeCache.get(cacheKey)
        }

        const isPostfach = this.isPostfachAddress(addr.strasse)

        if (isPostfach) {
            console.log(`  Postfach erkannt - nutze nur Ort`)
        }

        let coords = null

        if (addr.plz && !isPostfach) {
            console.log(`  Trying structured search with PLZ: ${addr.plz}`)
            coords = await this.tryGeocodeStructured(addr)
            if (coords) {
                this.geocodeCache.set(cacheKey, coords)
                return coords
            }
        }

        if (addr.plz) {
            console.log(`  Trying PLZ only: ${addr.plz}`)
            coords = await this.tryGeocodePLZOnly(addr.plz)
            if (coords) {
                this.geocodeCache.set(cacheKey, coords)
                return coords
            }
        }

        if (addr.ort) {
            console.log(`  Trying Ort only: ${addr.ort}`)
            coords = await this.tryGeocodeOrtOnly(addr.ort)
            if (coords) {
                this.geocodeCache.set(cacheKey, coords)
                return coords
            }
        }

        if (addr.plz && addr.ort) {
            const simpleQuery = `${addr.plz} ${addr.ort}, Germany`
            console.log(`  Trying PLZ + Ort: ${simpleQuery}`)
            coords = await this.tryGeocode(simpleQuery)
            if (coords) {
                this.geocodeCache.set(cacheKey, coords)
                return coords
            }
        }

        if (addr.ort) {
            const ortQuery = `${addr.ort}, Germany`
            console.log(`  Trying Ort as query: ${ortQuery}`)
            coords = await this.tryGeocode(ortQuery)
            if (coords) {
                this.geocodeCache.set(cacheKey, coords)
                return coords
            }
        }

        this.geocodeCache.set(cacheKey, null)
        return null
    }

    async tryGeocodeStructured(addr) {
        try {
            const params = new URLSearchParams({
                format: 'json',
                limit: '1',
                countrycodes: 'de'
            })

            if (addr.plz) params.append('postalcode', addr.plz)
            if (addr.ort) params.append('city', addr.ort)

            if (addr.strasse && !this.isPostfachAddress(addr.strasse)) {
                params.append('street', addr.strasse)
            }

            const url = `https://nominatim.openstreetmap.org/search?${params.toString()}`
            console.log(`    URL: ${url}`)

            const response = await fetch(url, {
                headers: { 'Accept-Language': 'de' }
            })
            const data = await response.json()

            if (data?.[0]) {
                return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
            }
            return null
        } catch (error) {
            console.warn('Structured geocoding error:', error)
            return null
        }
    }

    async tryGeocodePLZOnly(plz) {
        try {
            const url = `https://nominatim.openstreetmap.org/search?format=json&postalcode=${plz}&countrycodes=de&limit=1`
            console.log(`    URL: ${url}`)

            const response = await fetch(url, {
                headers: { 'Accept-Language': 'de' }
            })
            const data = await response.json()

            if (data?.[0]) {
                return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
            }
            return null
        } catch (error) {
            console.warn('PLZ geocoding error:', error)
            return null
        }
    }

    async tryGeocodeOrtOnly(ort) {
        try {
            const url = `https://nominatim.openstreetmap.org/search?format=json&city=${encodeURIComponent(ort)}&countrycodes=de&limit=1`
            console.log(`    URL: ${url}`)

            const response = await fetch(url, {
                headers: { 'Accept-Language': 'de' }
            })
            const data = await response.json()

            if (data?.[0]) {
                return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
            }
            return null
        } catch (error) {
            console.warn('Ort geocoding error:', error)
            return null
        }
    }

    async tryGeocode(query) {
        try {
            const response = await fetch(
                `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1&countrycodes=de`,
                { headers: { 'Accept-Language': 'de' } }
            )
            const data = await response.json()

            if (data?.[0]) {
                return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
            }
            return null
        } catch (error) {
            console.warn('Geocoding error for:', query, error)
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

    // Karte an alle Marker anpassen (inkl. Ladeort)
    fitMapToAllMarkers() {
        if (!this.map) return

        const allMarkers = []

        if (this.loadingLocationMarker) {
            allMarkers.push(this.loadingLocationMarker)
        }

        if (this.markers?.length > 0) {
            allMarkers.push(...this.markers.map(m => m.marker))
        }

        if (allMarkers.length > 0) {
            const group = L.featureGroup(allMarkers)
            this.map.fitBounds(group.getBounds().pad(0.1))
        }
    }

    fitMapToMarkers() {
        this.fitMapToAllMarkers()
    }

    // Route zeichnen: Ladeort → Lieferung 1 → Lieferung 2 → ...
    drawFullRoute() {
        if (!this.map) return

        const coordinates = []

        // Startpunkt: Ladeort
        if (this.loadingLocationCoords) {
            coordinates.push([this.loadingLocationCoords.lat, this.loadingLocationCoords.lng])
        }

        // Lieferungen in aktueller Reihenfolge
        if (this.markers?.length > 0) {
            this.markers.forEach(m => {
                if (m.address?.lat && m.address?.lng) {
                    coordinates.push([m.address.lat, m.address.lng])
                }
            })
        }

        if (coordinates.length >= 2) {
            this.drawSimpleRoute(coordinates)
        }
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

        const coordinates = []

        // Startpunkt: Ladeort
        if (this.loadingLocationCoords) {
            coordinates.push([this.loadingLocationCoords.lat, this.loadingLocationCoords.lng])
        }

        // Lieferungen in aktueller DOM-Reihenfolge
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
                this.loadingLocationMarker = null
                this.loadingLocationCoords = null
                this.routeLayer = null
            }, 300)
        }
    }
}