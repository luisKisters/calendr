import Testing
@testable import CalendrKit

/// v4 Phase 4: the text rules of an event block, at the mockup's thresholds (design/mockup-v4/index.html `grid()` :1270-1278).
@Suite("Block text plan")
struct BlockTextTests {
    @Test func underThirtyPointsIsOneRowWithTheStartTime() {
        let p = BlockText.plan(height: 29.9, width: 113, isShort: false)
        #expect(p.lines == .one && p.maxTitleLines == 1 && p.time == .start && !p.centered && !p.compact)
        #expect(BlockText.plan(height: 30, width: 113, isShort: false).lines == .stacked)
    }

    @Test func underTwentyTwoPointsTheRowIsCentred() {
        #expect(BlockText.plan(height: 21.9, width: 113, isShort: false).centered)
        #expect(!BlockText.plan(height: 22, width: 113, isShort: false).centered)
        #expect(!BlockText.plan(height: 35, width: 113, isShort: false).centered)   // only a one-row block centres
    }

    @Test func underFiftyTwoPointsTheTitleHasOneLine() {
        #expect(BlockText.plan(height: 51.9, width: 113, isShort: false).maxTitleLines == 1)
        #expect(BlockText.plan(height: 52, width: 113, isShort: false).maxTitleLines == 2)
    }

    @Test func underFortyPointsThePaddingIsCompact() {
        #expect(BlockText.plan(height: 39.9, width: 113, isShort: false).compact)
        #expect(!BlockText.plan(height: 40, width: 113, isShort: false).compact)
        #expect(!BlockText.plan(height: 25, width: 113, isShort: false).compact)     // one row: its own padding
    }

    @Test func narrowBlocksKeepOneTitleLineAndAOneRowBlockHidesTheTime() {
        let tall = BlockText.plan(height: 90, width: 55.9, isShort: false)
        #expect(tall.narrow && tall.maxTitleLines == 1 && tall.time == .start && !tall.hyphenate)
        let row = BlockText.plan(height: 20, width: 55.9, isShort: false)
        #expect(row.narrow && row.time == .none)
        #expect(!BlockText.plan(height: 90, width: 56, isShort: false).narrow)
    }

    @Test func theRangeNeedsSixtyTwoPointsAfterPadding() {
        #expect(BlockText.plan(height: 60, width: 79, isShort: false).time == .range)       // 79 - 17 = 62
        #expect(BlockText.plan(height: 60, width: 78.9, isShort: false).time == .start)
        #expect(BlockText.plan(height: 60, width: 200, isShort: true).time == .start)       // a short item says only when
    }

    @Test func onlyATwoLineTitleHyphenates() {
        #expect(BlockText.plan(height: 60, width: 113, isShort: false).hyphenate)
        #expect(!BlockText.plan(height: 45, width: 113, isShort: false).hyphenate)
        #expect(!BlockText.plan(height: 25, width: 113, isShort: false).hyphenate)
    }
}
