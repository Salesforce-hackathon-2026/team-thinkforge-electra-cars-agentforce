public class Electra_VehicleOptions {
    @AuraEnabled
    public String headerText;        // "Which model interests you?"

    @AuraEnabled
    public List<String> modelNames;  // ["Electra Sedan", "Electra SUV"]

    // A zero-argument constructor is required for Apex-Defined types in Flow
    public Electra_VehicleOptions() {}
}
