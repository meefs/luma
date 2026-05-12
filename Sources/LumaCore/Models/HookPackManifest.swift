import Foundation

public struct HookPackManifest: Codable, Sendable, Equatable {
    public enum Icon: Codable, Sendable, Equatable {
        case symbolic(String)
        case file(String)

        private enum CodingKeys: String, CodingKey { case kind, value }
        private enum Kind: String, Codable { case symbolic, file }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(Kind.self, forKey: .kind) {
            case .symbolic: self = .symbolic(try c.decode(String.self, forKey: .value))
            case .file: self = .file(try c.decode(String.self, forKey: .value))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .symbolic(let id):
                try c.encode(Kind.symbolic, forKey: .kind)
                try c.encode(id, forKey: .value)
            case .file(let path):
                try c.encode(Kind.file, forKey: .kind)
                try c.encode(path, forKey: .value)
            }
        }
    }

    public var name: String
    public var icon: Icon?
    public var compatibility: InstrumentCompatibility
    public var entrypoint: String
    public var features: [CustomInstrumentDef.Feature]
    public var widgets: [InstrumentWidget]

    public init(
        name: String,
        icon: Icon?,
        compatibility: InstrumentCompatibility = .universal,
        entrypoint: String,
        features: [CustomInstrumentDef.Feature],
        widgets: [InstrumentWidget]
    ) {
        self.name = name
        self.icon = icon
        self.compatibility = compatibility
        self.entrypoint = entrypoint
        self.features = features
        self.widgets = widgets
    }

    private enum CodingKeys: String, CodingKey {
        case name, icon, compatibility, entrypoint, features, widgets
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decodeIfPresent(Icon.self, forKey: .icon)
        compatibility = try c.decodeIfPresent(InstrumentCompatibility.self, forKey: .compatibility) ?? .universal
        entrypoint = try c.decode(String.self, forKey: .entrypoint)
        features = try c.decodeIfPresent([CustomInstrumentDef.Feature].self, forKey: .features) ?? []
        widgets = try c.decodeIfPresent([InstrumentWidget].self, forKey: .widgets) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(icon, forKey: .icon)
        if !compatibility.isUniversal {
            try c.encode(compatibility, forKey: .compatibility)
        }
        try c.encode(entrypoint, forKey: .entrypoint)
        try c.encode(features, forKey: .features)
        try c.encode(widgets, forKey: .widgets)
    }
}
