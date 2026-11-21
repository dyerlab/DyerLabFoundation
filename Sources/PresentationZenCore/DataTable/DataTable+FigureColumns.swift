//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTable+FigureColumns.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import TabularData

public extension DataTable {

    /// The table as columns a ``StoredFigure`` can hold, in order and with their roles.
    ///
    /// A column that is not a number, date or string becomes text.
    var figureColumns: [FigureColumn] {
        columnNames.map { name in
            let role = roles.first { $0.value == name }?.key
            switch kind(of: name) {
            case .number: return FigureColumn(name: name, role: role, values: .numbers(numericColumn(name)))
            case .date:
                return FigureColumn(name: name, role: role, values: .dates(Array(frame[name, Date.self])))
            case .category, .none: return FigureColumn(name: name, role: role, values: .text(stringColumn(name)))
            }
        }
    }

    /// Builds a table from a figure's stored columns.
    ///
    /// - Parameter columns: The columns, which must have unique names and equal lengths.
    /// - Returns: The table, or `nil` if the columns can't form one.
    init?(figureColumns columns: [FigureColumn]) {
        guard Set(columns.map(\.name)).count == columns.count,
              Set(columns.map(\.values.count)).count <= 1 else { return nil }
        var frame = DataFrame()
        var roles: [DataColumnRole: String] = [:]
        for column in columns {
            switch column.values {
            case .numbers(let values): frame.append(column: Column(name: column.name, contents: values))
            case .text(let values): frame.append(column: Column(name: column.name, contents: values))
            case .dates(let values): frame.append(column: Column(name: column.name, contents: values))
            }
            if let role = column.role { roles[role] = column.name }
        }
        self.init(frame: frame, roles: roles)
    }
}
