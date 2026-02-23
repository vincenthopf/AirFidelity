import XCTest
@testable import AirFidelity

final class CodecInfoTests: XCTestCase {

    func testA2DPCodecFromHighQualityDevice() throws {
        let device = DeviceInfo(
            id: "test-bt",
            name: "AirPods Pro",
            transportType: .bluetooth,
            nominalSampleRate: 48000,
            outputChannels: 2
        )
        let info = try XCTUnwrap(CodecInfo(from: device))

        XCTAssertEqual(info.codecName, "AAC")
        XCTAssertEqual(info.profileName, "A2DP")
        XCTAssertEqual(info.sampleRateDisplay, "48.0 kHz")
        XCTAssertEqual(info.channelDisplay, "Stereo")
        XCTAssertTrue(info.isHighQuality)
    }

    func testA2DPAt44100() throws {
        let device = DeviceInfo(
            id: "test-bt",
            name: "Sony WH-1000XM5",
            transportType: .bluetooth,
            nominalSampleRate: 44100,
            outputChannels: 2
        )
        let info = try XCTUnwrap(CodecInfo(from: device))

        XCTAssertEqual(info.codecName, "AAC")
        XCTAssertEqual(info.sampleRateDisplay, "44.1 kHz")
        XCTAssertTrue(info.isHighQuality)
    }

    func testHFPCodecFrom16kHzDevice() throws {
        let device = DeviceInfo(
            id: "test-bt",
            name: "AirPods Pro",
            transportType: .bluetooth,
            nominalSampleRate: 16000,
            outputChannels: 1
        )
        let info = try XCTUnwrap(CodecInfo(from: device))

        XCTAssertEqual(info.codecName, "SCO")
        XCTAssertEqual(info.profileName, "HFP")
        XCTAssertEqual(info.sampleRateDisplay, "16.0 kHz")
        XCTAssertEqual(info.channelDisplay, "Mono")
        XCTAssertFalse(info.isHighQuality)
    }

    func testHFPCodecFrom8kHzDevice() throws {
        let device = DeviceInfo(
            id: "test-bt",
            name: "AirPods Pro",
            transportType: .bluetooth,
            nominalSampleRate: 8000,
            outputChannels: 1
        )
        let info = try XCTUnwrap(CodecInfo(from: device))

        XCTAssertEqual(info.codecName, "SCO")
        XCTAssertEqual(info.sampleRateDisplay, "8.0 kHz")
        XCTAssertFalse(info.isHighQuality)
    }

    func testNonBluetoothDeviceReturnsNil() {
        let device = DeviceInfo(
            id: "built-in",
            name: "MacBook Pro Speakers",
            transportType: .builtIn,
            nominalSampleRate: 48000,
            outputChannels: 2
        )
        let info = CodecInfo(from: device)
        XCTAssertNil(info)
    }

    func testSummaryStringFormat() {
        let device = DeviceInfo(
            id: "test-bt",
            name: "AirPods Pro",
            transportType: .bluetooth,
            nominalSampleRate: 48000,
            outputChannels: 2
        )
        let info = CodecInfo(from: device)

        XCTAssertEqual(info?.summary, "AAC · 48.0 kHz · Stereo")
    }

    func testMissingSampleRate() {
        let device = DeviceInfo(
            id: "test-bt",
            name: "AirPods Pro",
            transportType: .bluetooth,
            nominalSampleRate: nil,
            outputChannels: 2
        )
        let info = CodecInfo(from: device)

        XCTAssertEqual(info?.codecName, "Unknown")
        XCTAssertEqual(info?.sampleRateDisplay, "— kHz")
    }
}
