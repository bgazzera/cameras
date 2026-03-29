import XCTest
@testable import HikvisionViewerMobile

final class HikvisionViewerMobileTests: XCTestCase {
    func testRtspURLBuilderNormalizesShortChannels() throws {
        let configuration = NVRConfiguration(host: "192.168.1.10", username: "admin", rtspPort: 554, httpPort: 80, selectedChannelID: "1")
        let url = try RTSPURLBuilder.buildURL(configuration: configuration, password: "secret", channelID: "1")

        XCTAssertEqual(url.absoluteString, "rtsp://admin:secret@192.168.1.10:554/Streaming/Channels/101?transportmode=unicast")
    }

    func testDoorbellCallStateRecognizesRingingState() {
        let state = DoorbellCallState(status: "incomingRing")

        XCTAssertTrue(state.isRinging)
        XCTAssertEqual(state.controlTitle, "Answer")
    }
}