import Foundation

// MARK: - TokenSerializationError

/// Errors that can occur during token serialization/deserialization.
public enum TokenSerializationError: Error, LocalizedError {
    /// The data could not be decoded.
    case decodingFailed(Error)
    /// The decoded result is empty, which would destroy existing data.
    case emptyResult
    /// The data is nil or zero-length.
    case noData

    public var errorDescription: String? {
        switch self {
        case .decodingFailed(let error):
            return "Token decoding failed: \(error.localizedDescription)"
        case .emptyResult:
            return "Decoded token set is empty — refusing to overwrite existing data"
        case .noData:
            return "No data provided for token deserialization"
        }
    }
}

// MARK: - TokenSerializer

/// Utility for safely serializing and deserializing token data
/// (app tokens, category tokens, web domain tokens) for storage
/// in App Group UserDefaults.
///
/// **Critical safety guarantee:** Deserialization validates that the result
/// is non-empty before allowing it to overwrite existing data. This prevents
/// permanent loss of blocking configuration from corrupted or empty data.
public enum TokenSerializer {

    // MARK: - Serialization

    /// Serialize a set of Data tokens to a single Data blob for storage.
    ///
    /// - Parameter tokens: The set of token data to serialize.
    /// - Returns: The serialized data, or `nil` if the set is empty.
    public static func serialize(tokens: Set<Data>) -> Data? {
        guard !tokens.isEmpty else { return nil }
        return try? JSONEncoder().encode(Array(tokens))
    }

    /// Serialize an array of Data tokens to a single Data blob for storage.
    ///
    /// - Parameter tokens: The array of token data to serialize.
    /// - Returns: The serialized data, or `nil` if the array is empty.
    public static func serialize(tokenArray: [Data]) -> Data? {
        guard !tokenArray.isEmpty else { return nil }
        return try? JSONEncoder().encode(tokenArray)
    }

    // MARK: - Deserialization

    /// Deserialize token data from storage.
    ///
    /// - Parameter data: The serialized data to decode.
    /// - Returns: A set of token Data values.
    /// - Throws: `TokenSerializationError` if decoding fails or result is empty.
    public static func deserialize(data: Data) throws -> Set<Data> {
        let array: [Data]
        do {
            array = try JSONDecoder().decode([Data].self, from: data)
        } catch {
            throw TokenSerializationError.decodingFailed(error)
        }

        guard !array.isEmpty else {
            throw TokenSerializationError.emptyResult
        }

        return Set(array)
    }

    // MARK: - Safe Update

    /// Safely update token data in UserDefaults, validating before overwriting.
    ///
    /// If the new data decodes to a non-empty set, it replaces the existing data.
    /// If the new data is nil, empty, or decodes to an empty set, the existing
    /// data is preserved (NOT overwritten).
    ///
    /// - Parameters:
    ///   - newData: The new serialized token data to store.
    ///   - key: The UserDefaults key to store the data under.
    ///   - defaults: The UserDefaults instance to use.
    /// - Returns: `true` if the data was updated, `false` if existing data was preserved.
    @discardableResult
    public static func safelyUpdateTokens(
        _ newData: Data?,
        forKey key: String,
        in defaults: UserDefaults
    ) -> Bool {
        guard let newData = newData, !newData.isEmpty else {
            // Don't overwrite with nil/empty data
            return false
        }

        do {
            let tokens = try deserialize(data: newData)
            // Only update if we got a valid non-empty set
            if !tokens.isEmpty {
                defaults.set(newData, forKey: key)
                return true
            }
            return false
        } catch {
            // Decoding failed or result is empty — preserve existing data
            return false
        }
    }

    /// Validate that token data is non-nil, non-empty, and decodes correctly.
    ///
    /// - Parameter data: The data to validate.
    /// - Returns: `true` if the data is valid token data.
    public static func isValid(data: Data?) -> Bool {
        guard let data = data, !data.isEmpty else { return false }
        do {
            let tokens = try deserialize(data: data)
            return !tokens.isEmpty
        } catch {
            return false
        }
    }
}
