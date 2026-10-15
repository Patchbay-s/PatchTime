import Foundation

extension Employer {
    var kmDistanceRoundTripValue: Double? {
        get { kmDistanceRoundTrip?.doubleValue }
        set { kmDistanceRoundTrip = newValue.map { NSNumber(value: $0) } }
    }
}
