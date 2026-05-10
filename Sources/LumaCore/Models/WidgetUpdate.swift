import Foundation

public struct WidgetUpdate: Sendable, Identifiable {
    public let id: UUID
    public let instanceID: UUID
    public let widget: String
    public let kind: Kind

    public init(id: UUID = UUID(), instanceID: UUID, widget: String, kind: Kind) {
        self.id = id
        self.instanceID = instanceID
        self.widget = widget
        self.kind = kind
    }

    public enum Kind: Sendable {
        case graphPoint(WidgetGraphPoint)
        case listUpsert(WidgetListItem)
        case listRemove(itemID: String)
        case tableUpsert(WidgetTableRow)
        case tableRemove(rowID: String)
        case counterSet(WidgetCounterValue)
        case histogramSet([WidgetHistogramBucket])
        case histogramIncrement(label: String, by: Double)
        case hexSet(WidgetHexState)
        case clear
    }

    public func toWireJSON() -> [String: Any] {
        var obj: [String: Any] = [
            "instance_id": instanceID.uuidString,
            "widget": widget,
        ]
        switch kind {
        case .graphPoint(let point):
            obj["kind"] = "graph-point"
            obj["point"] = ["series": point.series, "x": point.x, "y": point.y]
        case .listUpsert(let item):
            obj["kind"] = "list-upsert"
            var itemObj: [String: Any] = ["id": item.id, "title": item.title]
            if let s = item.subtitle { itemObj["subtitle"] = s }
            if let a = item.accessory { itemObj["accessory"] = a }
            obj["item"] = itemObj
        case .listRemove(let itemID):
            obj["kind"] = "list-remove"
            obj["item"] = itemID
        case .tableUpsert(let row):
            obj["kind"] = "table-upsert"
            obj["row"] = ["id": row.id, "cells": row.cells]
        case .tableRemove(let rowID):
            obj["kind"] = "table-remove"
            obj["row"] = rowID
        case .counterSet(let value):
            obj["kind"] = "counter-set"
            var counter: [String: Any] = ["value": value.value]
            if let unit = value.unit { counter["unit"] = unit }
            if let delta = value.delta { counter["delta"] = delta }
            obj["counter"] = counter
        case .histogramSet(let buckets):
            obj["kind"] = "histogram-set"
            obj["buckets"] = buckets.map { ["label": $0.label, "count": $0.count] }
        case .histogramIncrement(let label, let by):
            obj["kind"] = "histogram-increment"
            obj["label"] = label
            obj["by"] = by
        case .hexSet(let state):
            obj["kind"] = "hex-set"
            obj["hex"] = [
                "bytes": state.bytes.base64EncodedString(),
                "base_address": state.baseAddress,
            ]
        case .clear:
            obj["kind"] = "clear"
        }
        return obj
    }

    public static func fromWireJSON(_ obj: [String: Any]) -> WidgetUpdate? {
        guard let instanceIDStr = obj["instance_id"] as? String,
            let instanceID = UUID(uuidString: instanceIDStr),
            let widget = obj["widget"] as? String,
            let kindStr = obj["kind"] as? String
        else { return nil }
        guard let kind = decodeKind(kindStr, from: obj) else { return nil }
        return WidgetUpdate(instanceID: instanceID, widget: widget, kind: kind)
    }

    private static func decodeKind(_ kindStr: String, from obj: [String: Any]) -> Kind? {
        switch kindStr {
        case "graph-point":
            guard let pointObj = obj["point"] as? [String: Any],
                let series = pointObj["series"] as? String,
                let x = decodeDouble(pointObj["x"]),
                let y = decodeDouble(pointObj["y"])
            else { return nil }
            return .graphPoint(WidgetGraphPoint(series: series, x: x, y: y))
        case "list-upsert":
            guard let itemObj = obj["item"] as? [String: Any],
                let id = itemObj["id"] as? String,
                let title = itemObj["title"] as? String
            else { return nil }
            return .listUpsert(WidgetListItem(
                id: id,
                title: title,
                subtitle: itemObj["subtitle"] as? String,
                accessory: itemObj["accessory"] as? String
            ))
        case "list-remove":
            guard let itemID = obj["item"] as? String else { return nil }
            return .listRemove(itemID: itemID)
        case "table-upsert":
            guard let rowObj = obj["row"] as? [String: Any],
                let id = rowObj["id"] as? String,
                let cells = rowObj["cells"] as? [String: String]
            else { return nil }
            return .tableUpsert(WidgetTableRow(id: id, cells: cells))
        case "table-remove":
            guard let rowID = obj["row"] as? String else { return nil }
            return .tableRemove(rowID: rowID)
        case "counter-set":
            guard let counter = obj["counter"] as? [String: Any],
                let value = decodeDouble(counter["value"])
            else { return nil }
            return .counterSet(WidgetCounterValue(
                value: value,
                unit: counter["unit"] as? String,
                delta: decodeDouble(counter["delta"])
            ))
        case "histogram-set":
            guard let buckets = obj["buckets"] as? [[String: Any]] else { return nil }
            let parsed = buckets.compactMap { b -> WidgetHistogramBucket? in
                guard let label = b["label"] as? String, let count = decodeDouble(b["count"]) else { return nil }
                return WidgetHistogramBucket(label: label, count: count)
            }
            return .histogramSet(parsed)
        case "histogram-increment":
            guard let label = obj["label"] as? String, let by = decodeDouble(obj["by"]) else { return nil }
            return .histogramIncrement(label: label, by: by)
        case "hex-set":
            guard let hex = obj["hex"] as? [String: Any],
                let b64 = hex["bytes"] as? String,
                let bytes = Data(base64Encoded: b64)
            else { return nil }
            let baseAddress: UInt64 = (hex["base_address"] as? NSNumber)?.uint64Value ?? 0
            return .hexSet(WidgetHexState(bytes: bytes, baseAddress: baseAddress))
        case "clear":
            return .clear
        default:
            return nil
        }
    }

    private static func decodeDouble(_ raw: Any?) -> Double? {
        if let n = raw as? NSNumber { return n.doubleValue }
        return nil
    }
}

public struct WidgetGraphPoint: Codable, Sendable, Equatable {
    public let series: String
    public let x: Double
    public let y: Double

    public init(series: String, x: Double, y: Double) {
        self.series = series
        self.x = x
        self.y = y
    }
}

public struct WidgetListItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var subtitle: String?
    public var accessory: String?

    public init(id: String, title: String, subtitle: String? = nil, accessory: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }
}

public struct WidgetTableRow: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var cells: [String: String]

    public init(id: String, cells: [String: String]) {
        self.id = id
        self.cells = cells
    }
}

public struct WidgetCounterValue: Codable, Sendable, Equatable {
    public var value: Double
    public var unit: String?
    public var delta: Double?

    public init(value: Double, unit: String? = nil, delta: Double? = nil) {
        self.value = value
        self.unit = unit
        self.delta = delta
    }
}

public struct WidgetHistogramBucket: Codable, Sendable, Equatable {
    public let label: String
    public var count: Double

    public init(label: String, count: Double) {
        self.label = label
        self.count = count
    }
}

public struct WidgetHexState: Codable, Sendable, Equatable {
    public var bytes: Data
    public var baseAddress: UInt64

    public init(bytes: Data, baseAddress: UInt64 = 0) {
        self.bytes = bytes
        self.baseAddress = baseAddress
    }
}

public struct WidgetStateSnapshot: Sendable {
    public let sessionID: UUID
    public let instanceID: UUID
    public let widget: String
    public let state: WidgetState

    public init(sessionID: UUID, instanceID: UUID, widget: String, state: WidgetState) {
        self.sessionID = sessionID
        self.instanceID = instanceID
        self.widget = widget
        self.state = state
    }

    public static func fromWireJSON(_ obj: [String: Any]) -> WidgetStateSnapshot? {
        guard let sessionStr = obj["session_id"] as? String,
            let sessionID = UUID(uuidString: sessionStr),
            let instanceStr = obj["instance_id"] as? String,
            let instanceID = UUID(uuidString: instanceStr),
            let widget = obj["widget"] as? String,
            let stateObj = obj["state"] as? [String: Any]
        else { return nil }

        var graphSeries: [String: [WidgetGraphPoint]] = [:]
        if let pts = stateObj["points"] as? [[String: Any]] {
            for p in pts {
                guard let series = p["series"] as? String,
                    let x = (p["x"] as? NSNumber).map({ $0.doubleValue }),
                    let y = (p["y"] as? NSNumber).map({ $0.doubleValue })
                else { continue }
                graphSeries[series, default: []].append(WidgetGraphPoint(series: series, x: x, y: y))
            }
        }

        var listItems: [WidgetListItem] = []
        if let items = stateObj["items"] as? [[String: Any]] {
            for it in items {
                guard let id = it["id"] as? String, let title = it["title"] as? String else { continue }
                listItems.append(WidgetListItem(
                    id: id,
                    title: title,
                    subtitle: it["subtitle"] as? String,
                    accessory: it["accessory"] as? String
                ))
            }
        }

        var tableRows: [WidgetTableRow] = []
        if let rows = stateObj["rows"] as? [[String: Any]] {
            for row in rows {
                guard let id = row["id"] as? String, let cells = row["cells"] as? [String: String] else { continue }
                tableRows.append(WidgetTableRow(id: id, cells: cells))
            }
        }

        var counter: WidgetCounterValue?
        if let c = stateObj["counter"] as? [String: Any], let value = (c["value"] as? NSNumber)?.doubleValue {
            counter = WidgetCounterValue(
                value: value,
                unit: c["unit"] as? String,
                delta: (c["delta"] as? NSNumber)?.doubleValue
            )
        }

        var histogram: [WidgetHistogramBucket] = []
        if let buckets = stateObj["buckets"] as? [[String: Any]] {
            for b in buckets {
                guard let label = b["label"] as? String, let count = (b["count"] as? NSNumber)?.doubleValue else { continue }
                histogram.append(WidgetHistogramBucket(label: label, count: count))
            }
        }

        var hex: WidgetHexState?
        if let h = stateObj["hex"] as? [String: Any],
            let b64 = h["bytes"] as? String,
            let bytes = Data(base64Encoded: b64)
        {
            hex = WidgetHexState(
                bytes: bytes,
                baseAddress: (h["base_address"] as? NSNumber)?.uint64Value ?? 0
            )
        }

        return WidgetStateSnapshot(
            sessionID: sessionID,
            instanceID: instanceID,
            widget: widget,
            state: WidgetState(
                graphSeries: graphSeries,
                listItems: listItems,
                tableRows: tableRows,
                counter: counter,
                histogram: histogram,
                hex: hex
            )
        )
    }
}

public struct WidgetState: Codable, Sendable, Equatable {
    public var graphSeries: [String: [WidgetGraphPoint]]
    public var listItems: [WidgetListItem]
    public var tableRows: [WidgetTableRow]
    public var counter: WidgetCounterValue?
    public var histogram: [WidgetHistogramBucket]
    public var hex: WidgetHexState?

    public init(
        graphSeries: [String: [WidgetGraphPoint]] = [:],
        listItems: [WidgetListItem] = [],
        tableRows: [WidgetTableRow] = [],
        counter: WidgetCounterValue? = nil,
        histogram: [WidgetHistogramBucket] = [],
        hex: WidgetHexState? = nil
    ) {
        self.graphSeries = graphSeries
        self.listItems = listItems
        self.tableRows = tableRows
        self.counter = counter
        self.histogram = histogram
        self.hex = hex
    }

    public mutating func apply(_ kind: WidgetUpdate.Kind) {
        switch kind {
        case .graphPoint(let point):
            graphSeries[point.series, default: []].append(point)
        case .listUpsert(let item):
            if let index = listItems.firstIndex(where: { $0.id == item.id }) {
                listItems[index] = item
            } else {
                listItems.append(item)
            }
        case .listRemove(let id):
            listItems.removeAll { $0.id == id }
        case .tableUpsert(let row):
            if let index = tableRows.firstIndex(where: { $0.id == row.id }) {
                tableRows[index] = row
            } else {
                tableRows.append(row)
            }
        case .tableRemove(let id):
            tableRows.removeAll { $0.id == id }
        case .counterSet(let value):
            counter = value
        case .histogramSet(let buckets):
            histogram = buckets
        case .histogramIncrement(let label, let by):
            if let index = histogram.firstIndex(where: { $0.label == label }) {
                histogram[index].count += by
            } else {
                histogram.append(WidgetHistogramBucket(label: label, count: by))
            }
        case .hexSet(let value):
            hex = value
        case .clear:
            graphSeries.removeAll()
            listItems.removeAll()
            tableRows.removeAll()
            counter = nil
            histogram.removeAll()
            hex = nil
        }
    }

    public mutating func cap(to kind: InstrumentWidget.Kind) {
        switch kind {
        case .graph(let cfg):
            for (seriesID, points) in graphSeries where points.count > cfg.maxPoints {
                graphSeries[seriesID] = Array(points.suffix(cfg.maxPoints))
            }
        case .list(let cfg):
            if listItems.count > cfg.maxItems {
                listItems = Array(listItems.suffix(cfg.maxItems))
            }
        case .table(let cfg):
            if tableRows.count > cfg.maxRows {
                tableRows = Array(tableRows.suffix(cfg.maxRows))
            }
        case .counter:
            break
        case .histogram(let cfg):
            if histogram.count > cfg.maxBuckets {
                histogram = Array(histogram.suffix(cfg.maxBuckets))
            }
        case .hex(let cfg):
            if let h = hex, h.bytes.count > cfg.maxBytes {
                let drop = h.bytes.count - cfg.maxBytes
                hex = WidgetHexState(
                    bytes: h.bytes.suffix(cfg.maxBytes),
                    baseAddress: h.baseAddress &+ UInt64(drop)
                )
            }
        }
    }
}
