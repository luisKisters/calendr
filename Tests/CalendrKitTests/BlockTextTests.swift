import Testing
@testable import CalendrKit

/// v5 H: the text rule of an event block, at the locked v11 numbers (design/mockup-v11 app.js `evBlock`, rd.css round g).
@Suite("Block text plan (v11)")
struct BlockTextTests {
    /// A block as the week grid draws it at the locked 44 pt hour: `max(minutes / 60 × 44 - 2, 16)` tall (a short item spans 22 min).
    /// `coveredAfter`: a later block is drawn over it this many minutes in.
    static func block(_ minutes: Int, width: Double = 113.28, hour: Double = 44, short: Bool = false, coveredAfter: Int? = nil) -> (BlockTextPlan, Double) {
        let span = short ? 22 : minutes
        let h = max(Double(span) / 60 * hour - 2, 16)
        let shown = coveredAfter.map { Double($0) / 60 * hour }
        return (BlockText.plan(height: h, width: width, minutes: span, isShort: short, visibleHeight: shown), min(h, shown ?? h))
    }

    /// The text never needs more height than the block has (no clipped glyph): padding + the lines it draws, or a centred
    /// line box that shrinks to the block.
    static func fits(_ p: BlockTextPlan, _ h: Double) -> Bool {
        switch p.lines {
        case .one: return p.centered ? BlockText.oneLineBox(height: h) <= h : BlockText.padTop + BlockText.titleLine <= h
        case .stacked:
            return BlockText.padTop + Double(p.maxTitleLines) * BlockText.titleLine + (p.time == .none ? 0 : BlockText.timeGap + BlockText.timeLine) <= h
        }
    }

    @Test func fifteenMinutesIsOneCentredLineWithoutTime() {
        let (p, h) = Self.block(15, short: true)              // a short item: 22 min, 14.1 → 16 pt
        #expect(h == 16 && p.lines == .one && p.centered && p.time == .none && p.maxTitleLines == 1)
        #expect(Self.fits(p, h))
    }

    @Test func thirtyMinutesIsOneLineWithItsTopPadding() {
        let (p, h) = Self.block(30)                            // 20 pt: under `tall1` (21.5), so the line is centred
        #expect(p.lines == .one && p.centered && p.time == .none)
        let (q, hq) = Self.block(30, hour: 60)                 // 28 pt at a taller hour: the 3 pt top padding stays
        #expect(q.lines == .one && !q.centered)
        #expect(Self.fits(p, h) && Self.fits(q, hq))
    }

    @Test func fortyFiveMinutesStacksOnlyWhenBothLinesFit() {
        let (p, h) = Self.block(45)                            // 31 pt < minTwo 34.5: one line
        #expect(h == 31 && p.lines == .one && !p.centered)
        let (q, hq) = Self.block(45, hour: 52)                 // 37 pt: title + time on two lines
        #expect(hq >= BlockText.minTwo && q.lines == .stacked && q.maxTitleLines == 1 && q.time == .range)
        #expect(Self.fits(p, h) && Self.fits(q, hq))
    }

    @Test func sixtyMinutesIsTitleThenTime() {
        let (p, h) = Self.block(60)                            // 42 pt: one title line + the range below
        #expect(h == 42 && p.lines == .stacked && p.maxTitleLines == 1 && p.time == .range)
        let (q, hq) = Self.block(90)                           // 64 pt: two title lines
        #expect(q.maxTitleLines == 2 && q.hyphenate)
        #expect(Self.fits(p, h) && Self.fits(q, hq))
    }

    @Test func noClippedGlyphAcrossHeightsAndWidths() {
        for hour in [28.0, 44, 64, 96] {
            for minutes in stride(from: 5, through: 240, by: 5) {
                for width in [24.0, 50, 70, 100, 113.28, 160, 300] {
                    let (p, h) = Self.block(minutes, width: width, hour: hour, short: minutes <= 15)
                    #expect(Self.fits(p, h), "\(minutes) min at \(hour) pt/h, \(width) pt wide")
                }
            }
        }
    }

    @Test func aOneLineBlockShowsTheTimeInlineOnlyWhenWide() {
        #expect(Self.block(30, width: 113).0.time == .none)    // `notime` under 120 pt
        #expect(Self.block(30, width: 120).0.time == .start)   // `.ev.one`: the start time after the title
    }

    @Test func theRangeNeedsEightyFourPoints() {
        #expect(Self.block(60, width: 84).0.time == .range)
        #expect(Self.block(60, width: 83.9).0.time == .start)
        #expect(BlockText.plan(height: 60, width: 200, minutes: 60, isShort: true).time == .start)   // a short item says only when
    }

    @Test func aNarrowOneLineBlockKeepsOneClippedTitleLine() {
        let p = Self.block(30, width: 65.9).0
        #expect(p.narrow && p.lines == .one && p.time == .none)
        #expect(!Self.block(30, width: 66).0.narrow)
        #expect(Self.block(90, width: 29.9).0.thin && !Self.block(90, width: 30).0.thin)
    }

    /// mockup-v14 "titles wrap" and "the time could still be shown": a narrow block with room wraps its title over up to
    /// three lines and keeps its start time below.
    @Test func aNarrowTallBlockWrapsItsTitleAndShowsItsStart() {
        let (p, h) = Self.block(120, width: 50)                 // 86 pt tall, 50 pt wide (a crowded spot side by side)
        #expect(!p.narrow && p.lines == .stacked && p.maxTitleLines == 3 && p.time == .start && p.hyphenate)
        #expect(Self.fits(p, h))
        #expect(Self.block(90, width: 50).0.maxTitleLines == 2)  // 64 pt: two title lines and the time
        #expect(Self.block(120, width: 43.9).0.narrow)           // under 44 pt a wrapped title would be a letter a line
    }

    @Test func aBlockCoveredSoonKeepsOneLine() {
        let (p, h) = Self.block(135, coveredAfter: 30)          // Design review under Hiring sync, 30 minutes in
        #expect(p.lines == .one && !p.centered && p.time == .none)       // `one tall1 notime cut`
        #expect(Self.fits(p, h))
    }

    /// The text is planned on the part that shows: covered 90 minutes in, the title and the time fit above the later block.
    @Test func aBlockCoveredLateStillShowsItsTime() {
        let (p, h) = Self.block(150, coveredAfter: 90)
        #expect(p.lines == .stacked && p.time == .range && p.maxTitleLines == 2)
        #expect(Self.fits(p, h))
    }

    @Test func aContinuedEventShowsItsEnd() {
        #expect(BlockText.plan(height: 100, width: 113, minutes: 120, continuesFromPrevious: true).time == .until)
    }
}
