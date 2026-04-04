import Foundation

extension Error {
    /// Checks if this error indicates a network connectivity problem.
    /// Centralizes network error detection — add new URLError codes here only.
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
