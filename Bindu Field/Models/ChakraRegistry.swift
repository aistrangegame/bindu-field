import Foundation

/// The 33 nodes + the connection graph, ported verbatim from
/// `design_handoff_lalita_pass/Bindu Map.html`. Coordinates are in the
/// design's 393 × 780 canvas; `MapView` scales them to the device.
enum ChakraRegistry {
    /// The nine chakras that have an authored dance today. Drives the
    /// `available`/`locked` split in `ChakraJourneyStore.state(for:)`.
    /// Matches the 9 chakras shipped in `ChakraData.all`.
    static let composedIDs: Set<String> = [
        "sahasrara", "ajna", "vishuddha", "anahata",
        "manipura", "svadhisthana", "muladhara", "maya", "aatma",
    ]

    /// All 33 nodes.
    static let all: [ChakraNode] = [
        // ── ENERGY SYSTEM (7) — the living spine
        ChakraNode(id: "sahasrara",    name: "Sahasrara",     skt: "सहस्रार",    system: .energy, hue: 280, canvasX: 196, canvasY: 108, essence: "thousand-petalled · the open above",            tier: 1),
        ChakraNode(id: "ajna",         name: "Ajna",          skt: "आज्ञा",       system: .energy, hue: 50,  canvasX: 196, canvasY: 192, essence: "the command · the eye that sees through both",  tier: 1),
        ChakraNode(id: "vishuddha",    name: "Vishuddha",     skt: "विशुद्ध",     system: .energy, hue: 185, canvasX: 196, canvasY: 278, essence: "the purified · what speaks from within",        tier: 1),
        ChakraNode(id: "anahata",      name: "Anahata",       skt: "अनाहत",       system: .energy, hue: 195, canvasX: 196, canvasY: 364, essence: "the unstruck sound · the heart that knows",     tier: 1),
        ChakraNode(id: "manipura",     name: "Manipura",      skt: "मणिपूर",      system: .energy, hue: 25,  canvasX: 196, canvasY: 448, essence: "the jewel city · the sun within",               tier: 1),
        ChakraNode(id: "svadhisthana", name: "Svadhisthana",  skt: "स्वाधिष्ठान", system: .energy, hue: 210, canvasX: 196, canvasY: 532, essence: "one's own dwelling · the sacred tide",          tier: 1),
        ChakraNode(id: "muladhara",    name: "Muladhara",     skt: "मूलाधार",     system: .energy, hue: 15,  canvasX: 196, canvasY: 616, essence: "the root support · the ground you stand on",    tier: 1),

        // ── BODY SYSTEM (10) — the extended subtle body
        ChakraNode(id: "bindu",          name: "Bindu",          skt: "बिन्दु",         system: .body, hue: 265, canvasX: 196, canvasY: 52,  essence: "the seed drop · where form and formless meet",      tier: 2),
        ChakraNode(id: "soma",           name: "Soma",           skt: "सोम",            system: .body, hue: 280, canvasX: 130, canvasY: 84,  essence: "the moon gate · nectar of pure knowing",            tier: 2),
        ChakraNode(id: "guru",           name: "Guru",           skt: "गुरु",           system: .body, hue: 280, canvasX: 262, canvasY: 84,  essence: "the inner teacher · remover of darkness",           tier: 2),
        ChakraNode(id: "manas",          name: "Manas",          skt: "मनस",            system: .body, hue: 50,  canvasX: 118, canvasY: 163, essence: "the sense-mind · where impressions gather",         tier: 2),
        ChakraNode(id: "lalana",         name: "Lalana",         skt: "ललना",           system: .body, hue: 185, canvasX: 274, canvasY: 163, essence: "the taste center · the secondary palate",            tier: 2),
        ChakraNode(id: "brahmarandhra",  name: "Brahmarandhra",  skt: "ब्रह्मरन्ध्र",   system: .body, hue: 280, canvasX: 88,  canvasY: 116, essence: "the gate of brahman · the crown opening",            tier: 2),
        ChakraNode(id: "nirvana",        name: "Nirvana",        skt: "निर्वाण",        system: .body, hue: 190, canvasX: 305, canvasY: 116, essence: "liberation · the flame that does not burn",          tier: 2),
        ChakraNode(id: "pada",           name: "Pada",           skt: "पद",             system: .body, hue: 15,  canvasX: 130, canvasY: 630, essence: "the sole ground · the foot print of the body",      tier: 2),
        ChakraNode(id: "musti",          name: "Musti",          skt: "मुष्टि",         system: .body, hue: 25,  canvasX: 262, canvasY: 630, essence: "the fist · the strength held in form",               tier: 2),
        ChakraNode(id: "kanda",          name: "Kanda",          skt: "कन्द",           system: .body, hue: 15,  canvasX: 196, canvasY: 688, essence: "the root bulb · where all nadis begin",              tier: 2),

        // ── MIND SYSTEM (9) — the mental field
        ChakraNode(id: "atichandra",    name: "Atichandra",    skt: "अतिचन्द्र",     system: .mind, hue: 280, canvasX: 54,  canvasY: 124, essence: "beyond moon · the super-lunar field",            tier: 3),
        ChakraNode(id: "vyapini",       name: "Vyapini",       skt: "व्यापिनी",      system: .mind, hue: 280, canvasX: 340, canvasY: 124, essence: "the pervader · all-present awareness",           tier: 3),
        ChakraNode(id: "mahanada",      name: "Mahanada",      skt: "महानाद",        system: .mind, hue: 185, canvasX: 42,  canvasY: 208, essence: "the great sound · primordial resonance",         tier: 3),
        ChakraNode(id: "nada",          name: "Nada",          skt: "नाद",           system: .mind, hue: 185, canvasX: 352, canvasY: 208, essence: "inner sound · the unstruck tone within",         tier: 3),
        ChakraNode(id: "samanai",       name: "Samanai",       skt: "समनाई",         system: .mind, hue: 195, canvasX: 48,  canvasY: 330, essence: "equanimity · the balanced witness field",        tier: 3),
        ChakraNode(id: "unmani",        name: "Unmani",        skt: "उन्मनी",        system: .mind, hue: 190, canvasX: 346, canvasY: 330, essence: "beyond mind · the unconditioned field",          tier: 3),
        ChakraNode(id: "nadi",          name: "Nadi",          skt: "नाडी",          system: .mind, hue: 210, canvasX: 56,  canvasY: 472, essence: "the channel · energy pathways through form",     tier: 3),
        ChakraNode(id: "binduvisarga",  name: "Bindu Visarga", skt: "बिन्दु विसर्ग", system: .mind, hue: 265, canvasX: 337, canvasY: 472, essence: "the falling drop · the release point",           tier: 3),
        ChakraNode(id: "chandra",       name: "Chandra",       skt: "चन्द्र",        system: .mind, hue: 50,  canvasX: 196, canvasY: 748, essence: "the moon mind · cooling, reflecting, receiving", tier: 3),

        // ── TREE OF LIFE (7) — the structural spine
        ChakraNode(id: "kether",  name: "Kether",  skt: "केतर",   system: .tree, hue: 280, canvasX: 196, canvasY: 20,  essence: "the crown · the first and final light",       tier: 4),
        ChakraNode(id: "chokmah", name: "Chokmah", skt: "चोकमाह", system: .tree, hue: 50,  canvasX: 72,  canvasY: 54,  essence: "wisdom · the flash before thought",           tier: 4),
        ChakraNode(id: "binah",   name: "Binah",   skt: "बिनाह",  system: .tree, hue: 265, canvasX: 321, canvasY: 54,  essence: "understanding · form receiving formless",      tier: 4),
        ChakraNode(id: "maya",    name: "Maya",    skt: "माया",   system: .tree, hue: 190, canvasX: 80,  canvasY: 462, essence: "the veil · what dissolves when truly seen",    tier: 4),
        ChakraNode(id: "aatma",   name: "Aatma",   skt: "आत्मा",  system: .tree, hue: 265, canvasX: 313, canvasY: 462, essence: "the soul · the witness behind every witness",  tier: 4),
        ChakraNode(id: "yesod",   name: "Yesod",   skt: "येसोद",  system: .tree, hue: 210, canvasX: 88,  canvasY: 548, essence: "foundation · the dream layer of form",         tier: 4),
        ChakraNode(id: "malkuth", name: "Malkuth", skt: "मलकुत",  system: .tree, hue: 15,  canvasX: 305, canvasY: 548, essence: "kingdom · the sacred in the ordinary",         tier: 4),
    ]

    /// Connection edges. Each tuple references node ids from `all`.
    static let connections: [(String, String)] = [
        // Tree of Life crown
        ("kether", "chokmah"), ("kether", "binah"), ("kether", "bindu"),
        ("chokmah", "soma"), ("binah", "guru"),
        ("chokmah", "brahmarandhra"), ("binah", "nirvana"),
        ("chokmah", "atichandra"), ("binah", "vyapini"),
        // Crown cluster
        ("bindu", "sahasrara"), ("soma", "sahasrara"), ("guru", "sahasrara"),
        ("brahmarandhra", "sahasrara"), ("nirvana", "sahasrara"),
        ("atichandra", "brahmarandhra"), ("vyapini", "nirvana"),
        // Crown → Third Eye
        ("sahasrara", "ajna"),
        ("manas", "sahasrara"), ("lalana", "sahasrara"),
        ("atichandra", "manas"), ("vyapini", "lalana"),
        ("manas", "ajna"), ("lalana", "ajna"),
        ("mahanada", "ajna"), ("nada", "ajna"),
        // Third Eye → Throat
        ("ajna", "vishuddha"),
        ("mahanada", "samanai"), ("nada", "unmani"),
        // Throat → Heart
        ("vishuddha", "anahata"),
        ("samanai", "vishuddha"), ("unmani", "vishuddha"),
        ("samanai", "anahata"), ("unmani", "anahata"),
        // Heart → Solar
        ("anahata", "manipura"),
        ("maya", "manipura"), ("aatma", "manipura"),
        ("nadi", "maya"), ("binduvisarga", "aatma"),
        // Solar → Sacral
        ("manipura", "svadhisthana"),
        ("yesod", "svadhisthana"), ("malkuth", "svadhisthana"),
        ("nadi", "yesod"), ("binduvisarga", "malkuth"),
        // Sacral → Root
        ("svadhisthana", "muladhara"),
        ("yesod", "pada"), ("malkuth", "musti"),
        // Root cluster
        ("muladhara", "pada"), ("muladhara", "musti"), ("muladhara", "kanda"),
        ("pada", "kanda"), ("musti", "kanda"),
        ("kanda", "chandra"),
    ]

    /// Lookup by id. O(1) — backed by a lazy dictionary built once.
    static func node(id: String) -> ChakraNode? {
        Self.index[id]
    }

    private static let index: [String: ChakraNode] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    /// Canvas the coordinates are authored in.
    static let designCanvasWidth: Double = 393
    static let designCanvasHeight: Double = 780
}
