import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import getVehicleDetail from '@salesforce/apex/ElectraCmsController.getVehicleDetail';

export default class ElectraVehicleDetail extends NavigationMixin(LightningElement) {
    contentKey;
    vehicle;
    error;

    // "Invisible" fallback variables
    @track fallbackLat;
    @track fallbackLon;
    @track fallbackCity;

    // Automatically reads the ?contentKey=xxxx from the URL
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.contentKey = currentPageReference.state?.contentKey;
        }
    }

    // Calls the Apex class for car details
    @wire(getVehicleDetail, { contentKey: '$contentKey' })
    wiredVehicle({ error, data }) {
        if (data) {
            this.vehicle = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'Unknown Error';
            console.error('CMS Detail Error:', this.error);
        }
    }

    // Navigates back to the Home/Showroom
    navigateToHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home'
            }
        });
    }

    // Capture location silently as soon as the page loads
    connectedCallback() {
        this.captureInvisibleLocation();
    }

    async captureInvisibleLocation() {
        try {
            // Fetching approximate location via IP (No prompt required)
            const response = await fetch('https://ipapi.co/json/');
            const data = await response.json();
            
            this.fallbackLat = data.latitude;
            this.fallbackLon = data.longitude;
            this.fallbackCity = data.city;
            
            console.log('✓ Invisible Location Cached:', this.fallbackCity);
        } catch (e) {
            console.warn('Silent location capture failed:', e);
        }
    }


    // Entry point for the "Book" button
    handleBooking() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const lat = position.coords.latitude;
                    const lon = position.coords.longitude;
                    
                    // FIX: Explicitly check if coordinates are actually provided
                    // If browser says 'success' but GPS hardware returns null/0
                    if (lat != null && lon != null) {
                        console.log('✅ GPS Location Acquired');
                        this.executeNavigation(lat, lon);
                    } else {
                        console.warn('⚠️ GPS Success but coordinates null. Falling back to IP.');
                        this.executeNavigation(this.fallbackLat, this.fallbackLon);
                    }
                },
                (error) => {
                    // This catches Permission Denied, System Location Off, or Timeouts
                    console.warn('❌ Geolocation error: ', error.message);
                    this.executeNavigation(this.fallbackLat, this.fallbackLon);
                },
                { 
                    enableHighAccuracy: false, // Setting to false helps if GPS hardware is disabled
                    timeout: 5000,
                    maximumAge: 10000 
                } 
            );
        } else {
            // Browser doesn't support GPS: Use IP fallback
            this.executeNavigation(this.fallbackLat, this.fallbackLon);
        }
    }

    // Helper method (Now correctly placed as a sibling method)
    executeNavigation(lat, lon) {
        // 1. ERASE THE BOARD FIRST
        // This ensures no "ghost" data from previous car views remains
        sessionStorage.removeItem('electra_lat');
        sessionStorage.removeItem('electra_lon');
        sessionStorage.removeItem('electra_city');
        
        // 2. Get the values: Use GPS coords if available, otherwise use IP fallback
        // If incoming lat/lon is null/undefined, use the cached IP fallback
            //const finalLat = lat || this.fallbackLat;
            //const finalLon = lon || this.fallbackLon;
        const finalLat = (lat != null) ? lat : this.fallbackLat;
        const finalLon = (lon != null) ? lon : this.fallbackLon;

        console.log('🚀 Navigating with context:', { 
            lat: finalLat, 
            lon: finalLon, 
            city: this.fallbackCity 
        });

        // 3. "Hide" the data in Session Storage instead of the URL
        if (finalLat) sessionStorage.setItem('electra_lat', finalLat);
        if (finalLon) sessionStorage.setItem('electra_lon', finalLon);
        if (this.fallbackCity) sessionStorage.setItem('electra_city', this.fallbackCity);

        // 4. Proceed to Navigation: Use the Page API Name from Experience Builder
        // This automatically handles the "/ElectraCarsWeb/s/" prefix for you!
        const pageRef = {
            type: 'comm__namedPage',
            attributes: {
                name: 'Concierge__c' // Verify this API name in Builder Settings
            },
            state: {
                contentKey: this.contentKey
            }
        };

        // 5. Generate the URL and open in a new tab
        this[NavigationMixin.GenerateUrl](pageRef)
            .then(url => {
                window.open(url, '_blank');
            })
            .catch(error => {
                console.error('Navigation Error:', error);
            });

    }
}
