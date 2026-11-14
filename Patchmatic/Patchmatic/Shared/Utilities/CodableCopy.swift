import Foundation

func jsonSnapshot<T: Codable>(_ value: T) -> Data? {
    try? JSONEncoder().encode(value)
}

func restoreFromSnapshot<T: Codable>(_ data: Data, as type: T.Type) -> T? {
    try? JSONDecoder().decode(type, from: data)
}
