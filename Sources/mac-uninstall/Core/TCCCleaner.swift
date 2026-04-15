import Foundation
import CSQLite3

struct TCCCleaner {
    static func findEntries(bundleID: String, dbPath: String) -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "SELECT service FROM access WHERE client = ?;"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (bundleID as NSString).utf8String, -1, nil)

        var services: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                services.append(String(cString: cStr))
            }
        }
        return services
    }

    static func removeEntries(bundleID: String, dbPath: String) -> (removed: Int, errors: [String]) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            let errMsg = db.map { String(cString: sqlite3_errmsg($0)!) } ?? "unknown error"
            return (0, ["Could not open TCC database: \(errMsg)"])
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "DELETE FROM access WHERE client = ?;"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return (0, ["Could not prepare TCC delete: \(String(cString: sqlite3_errmsg(db)!))"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (bundleID as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            return (Int(sqlite3_changes(db)), [])
        } else {
            return (0, ["TCC delete failed: \(String(cString: sqlite3_errmsg(db)!))"])
        }
    }
}
