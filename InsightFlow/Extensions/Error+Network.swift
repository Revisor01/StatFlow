import Foundation

extension Error {
    /// true bei Netzwerkfehlern; neue URLError-Codes nur hier ergänzen.
    var isNetworkError: Bool {
        guard let urlError = self as? URLError else { return false }
        return [
            .notConnectedToInternet,
            .networkConnectionLost,
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost
        ].contains(urlError.code)
    }
}
