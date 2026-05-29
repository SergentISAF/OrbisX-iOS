import Foundation

/// Simpel UserDefaults-cache med tidsstempler.
/// Brug til at gemme API-svar lokalt så app'en åbner med sidste kendte data
/// før vi henter friske fra serveren.
enum Cache {
    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(Date(), forKey: key + ".timestamp")
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func timestamp(_ key: String) -> Date? {
        UserDefaults.standard.object(forKey: key + ".timestamp") as? Date
    }

    static func clear(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + ".timestamp")
    }
}
