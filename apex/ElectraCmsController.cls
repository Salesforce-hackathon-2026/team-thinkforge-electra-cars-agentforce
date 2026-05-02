public WITHOUT SHARING class ElectraCmsController {

    /**
     * Returns a public delivery URL for a CMS asset using its Content Key.
     * Used for the hero video delivery.
     */
    @AuraEnabled(cacheable=true)
    public static String getCmsDeliveryUrlByContentKey(String contentKey) {
        if (String.isBlank(contentKey)) {
            throw new AuraHandledException('contentKey is required');
        }
        String key = contentKey.trim();
        if (key.length() < 10) {
            throw new AuraHandledException('Invalid CMS content key');
        }
        String cdnHost = 'orgfarm-543580c7c8.cdn.salesforce-experience.com';
        String fileName = 'Electra_Cars_night_drive_feel_video_actual.mp4';
        return 'https://' + cdnHost + '/cms/delivery/media/' + key + '/' + fileName;
    }

    /**
     * Helper to ensure URLs are site-ready for guest users.
     */
    private static String siteFriendly(String url) {
        if (String.isBlank(url)) return '';
        if (url.startsWith('http://') || url.startsWith('https://')) return url;
        if (url.startsWith('/sfsites/')) return url;
        return '/sfsites/c' + url;
    }

    /**
     * Fetches the collection of cars for the Home Page Grid.
     * Keeps your working "Double-Unwrap" logic.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCmsFeaturedVehicles(String collectionKey) {
        String siteId = Site.getSiteId();
        List<Map<String, String>> vehicleList = new List<Map<String, String>>();
        
        try {
            ConnectApi.ManagedContentCollectionItems collection = ConnectApi.ManagedContentDelivery.getCollectionItemsForSite(
                siteId, collectionKey, 'en_US'
            );

            for (ConnectApi.ManagedContentCollectionItem item : collection.items) {
                Map<String, String> v = new Map<String, String>();
                // Using .id (08C...) is the most stable way to link to the detail page
                v.put('contentKey', item.id);
                v.put('title', item.name);

                if (item.body != null) {
                    Map<String, Object> topBody = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(item.body);
                    if (topBody.containsKey('contentBody')) {
                        Map<String, Object> nodes = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(topBody.get('contentBody'));
                        
                        //if (nodes.containsKey('Starting_Price')) v.put('price', String.valueOf(nodes.get('Starting_Price')));
                        //if (nodes.containsKey('Catchy_Line')) v.put('tagline', String.valueOf(nodes.get('Catchy_Line')));
                        
                        // Use safe helper to avoid "Unable to load" errors if text is Rich Text
                        v.put('price', getSafeString(nodes, 'Starting_Price'));
                        v.put('tagline', getSafeString(nodes, 'Catchy_Line'));

                        if (nodes.containsKey('Model_Image')) {
                            Map<String, Object> media = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(nodes.get('Model_Image'));
                            if (media != null && media.containsKey('url')) {
                                v.put('imageUrl', '/sfsites/c' + String.valueOf(media.get('url')));
                            }
                        }
                    }
                }
                vehicleList.add(v);
            }
        } catch (Exception e) { 
            throw new AuraHandledException('CMS Grid Error: ' + e.getMessage()); 
        }
        return vehicleList;
    }

    /**
     * NEW: Fetches full details for a single vehicle for the Explore Page.
     * Uses exact API Names from image_7f1f8b.png.
     * FINAL VERSION: Resolved the ApexMapWrapper conversion error
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getVehicleDetail(String contentKey) {
        String siteId = Site.getSiteId();
        Map<String, String> vehicle = new Map<String, String>();
    
        try {
            // FIX: Changed return type to ManagedContentDeliveryDocument
            ConnectApi.ManagedContentDeliveryDocument content = ConnectApi.ManagedContentDelivery.getManagedContentForSite(
            siteId, contentKey, 'en_US', false
            );

            // Map the title directly
            vehicle.put('title', content.title);

            // In DeliveryDocument, the fields are already in the 'contentBody' Map
            if (content.contentBody != null) {
                // THE FIX: Explicitly unwrap the ApexMapWrapper before casting to Map
                Map<String, Object> nodes = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(content.contentBody);
            
                // Text Mappings (Using your API Names from image_7f1f8b.png)
                vehicle.put('price', getSafeString(nodes, 'Starting_Price'));
                vehicle.put('tagline', getSafeString(nodes, 'Catchy_Line'));
                vehicle.put('features', getSafeString(nodes, 'Features_Summary'));
                vehicle.put('interior', getSafeString(nodes, 'Interior_Detail'));
                vehicle.put('exterior', getSafeString(nodes, 'Exterior_Detail'));
                vehicle.put('vehicleAssetId', getSafeString(nodes, 'Vehicle_Asset_ID'));
            
                // Image Mapping - Delivery API uses a slightly different node structure for media
                if (nodes.containsKey('Model_Image')) {
                    // Unwrap the media node as well to be safe
                    Map<String, Object> media = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(nodes.get('Model_Image'));
                    if (media != null && media.containsKey('url')) {
                        // For DeliveryDocument, the URL is usually already formatted
                        String rawUrl = String.valueOf(media.get('url'));
                        vehicle.put('imageUrl', rawUrl.startsWith('/') ? '/sfsites/c' + rawUrl : rawUrl);
                    }
                }

                if (nodes.containsKey('Interior_image_view')) {
                    Map<String, Object> media = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(nodes.get('Interior_image_view'));
                    if (media != null && media.containsKey('url')) {
                        vehicle.put('interiorImageUrl', '/sfsites/c' + String.valueOf(media.get('url')));
                    }
                }

                if (nodes.containsKey('Exterior_image_view')) {
                    Map<String, Object> media = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(nodes.get('Exterior_image_view'));
                    if (media != null && media.containsKey('url')) {
                        vehicle.put('exteriorImageUrl', '/sfsites/c' + String.valueOf(media.get('url')));
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('CMS Detail Error: ' + e.getMessage());
        }
        return vehicle;
    }

    /**
     * PRIVATE HELPER: This is the "Safety Net."
     * Enhanced CMS fields (Rich Text/Text Area) return as Maps. 
     * This logic detects that and extracts the 'value' correctly.
     * THE SAFETY NET: Essential for Enhanced CMS fields that return as Objects/Maps
     */
    private static String getSafeString(Map<String, Object> nodes, String key) {
        if (!nodes.containsKey(key) || nodes.get(key) == null) return '';
        
        // Unwrap the individual node value in case it's also wrapped
        Object val = ConnectApi.ConnectUtilities.unwrapApexWrapper(nodes.get(key));
        String result = '';
        
        // In Enhanced CMS, fields often return as a Map with a 'value' key
        if (val instanceof Map<String, Object>) {
            Map<String, Object> valMap = (Map<String, Object>)val;
            return valMap.containsKey('value') ? String.valueOf(valMap.get('value')) : '';
        } else {
            result = String.valueOf(val);
        }

        if (String.isNotBlank(result)) {
            // 1. Handle actual newlines if they exist
            result = result.replace('\r\n', '\n');

            // 2. THE SMART BREAK: Force a line break before every asterisk 
            // Instead of adding <br/> for every asterisk, we just replace them with bullets first.
            // This ensures the existing newlines in the data handle the single-spacing.
            result = result.replace('* ', '• ');
            result = result.replace('*', '• ');
        
            // 3. Clean up leading breaks that cause misalignment
            //while (result.startsWith('<br/>')) {
            //    result = result.substring(5);
            //}

            // 3. The "Breathing Room" Logic:
            // We want a double break BEFORE the first bullet if there is text above it.
            if (result.contains('•')) {
                Integer firstBullet = result.indexOf('•');
                if (firstBullet > 0) {
                    String before = result.substring(0, firstBullet);
                    String after = result.substring(firstBullet);
                    // Ensure there are exactly two newlines before the first bullet
                    result = before.trim() + '\n\n' + after;
                }

                // We want a double break AFTER the last bullet if there is text below it.
                Integer lastBulletLineEnd = result.lastIndexOf('\n', result.lastIndexOf('•'));
                // If the text ends with more than just the list, we add padding at the end
                // (Note: This is usually handled by your design, but here it is for safety)
            }

            // 5. Final Conversion to HTML
            // This turns single newlines into single <br/> tags
            result = result.replace('\n', '<br/>');
        
            // 6. Cleanup: Remove any triple/quadruple breaks caused by the trim/append
            result = result.replace('<br/><br/><br/>', '<br/><br/>');
    
        }

        
        // If it's just a simple string
        //return String.valueOf(val);
        return result.trim();
    }

    /**
    * Fetches a single image URL from CMS (used for the Logo).
    */
    @AuraEnabled(cacheable=true)
    public static String getCmsImageUrl(String contentKey) {
        String siteId = Site.getSiteId();
        try {
            ConnectApi.ManagedContentDeliveryDocument content = ConnectApi.ManagedContentDelivery.getManagedContentForSite(
            siteId, contentKey, 'en_US', false
            );
        
            // Use the same 'unwrapping' logic we used for the car images
            Map<String, Object> nodes = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(content.contentBody);
        
            // For standard "Image" content types, the node is usually named 'source' or the API name you gave it
            // If your logo content type node is named differently, update 'source' below
            if (nodes.containsKey('source')) {
                Map<String, Object> media = (Map<String, Object>)ConnectApi.ConnectUtilities.unwrapApexWrapper(nodes.get('source'));
                return '/sfsites/c' + String.valueOf(media.get('url'));
            }
        } catch (Exception e) {
            return ''; // Fallback to empty if not found
        }
        return '';
    }

}
