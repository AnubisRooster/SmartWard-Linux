import CSQLite
import Foundation

struct SQLiteError: Error, CustomStringConvertible {
    let message: String
    var description: String { "SQLite: \(message)" }
}

/// A single SQLite connection. Callers serialise access (see `ModelContainer`).
final class SQLiteDatabase: @unchecked Sendable {
    private var handle: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open \(path)"
            sqlite3_close(handle)
            throw SQLiteError(message: message)
        }
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "exec failed"
            sqlite3_free(error)
            throw SQLiteError(message: message)
        }
    }

    enum Value {
        case text(String)
        case blob(Data)
        case int(Int)
        case null
    }

    /// Runs `sql` with `values` bound and calls `row` for each result row.
    func run(_ sql: String, _ values: [Value] = [], row: ((Statement) throws -> Void)? = nil) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw SQLiteError(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        for (index, value) in values.enumerated() {
            let i = Int32(index + 1)
            switch value {
            case .text(let s): sqlite3_bind_text(stmt, i, s, -1, Self.transient)
            case .int(let n): sqlite3_bind_int64(stmt, i, Int64(n))
            case .null: sqlite3_bind_null(stmt, i)
            case .blob(let d):
                _ = d.withUnsafeBytes { raw in
                    sqlite3_bind_blob(stmt, i, raw.baseAddress, Int32(d.count), Self.transient)
                }
            }
        }
        while true {
            switch sqlite3_step(stmt) {
            case SQLITE_ROW: try row?(Statement(stmt))
            case SQLITE_DONE: return
            default: throw SQLiteError(message: String(cString: sqlite3_errmsg(handle)))
            }
        }
    }

    struct Statement {
        let stmt: OpaquePointer
        init(_ stmt: OpaquePointer) { self.stmt = stmt }

        func text(_ column: Int32) -> String {
            sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
        }

        func data(_ column: Int32) -> Data {
            guard let bytes = sqlite3_column_blob(stmt, column) else { return Data() }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, column)))
        }

        func int(_ column: Int32) -> Int { Int(sqlite3_column_int64(stmt, column)) }
    }
}
