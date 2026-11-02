import Foundation

let tests: [(String, () throws -> Void)] = [
    ("CaptionTests.testCaptionUsesHalfOpenTimeRange", CaptionTests.testCaptionUsesHalfOpenTimeRange),
    ("CaptionTests.testBlankCaptionIsNeverActive", CaptionTests.testBlankCaptionIsNeverActive),
    ("CaptionTests.testRendererDrawsOnlyActiveCaptions", CaptionTests.testRendererDrawsOnlyActiveCaptions),
    ("ExportCompressionTests.testLargeResultReducesWidthAndFrameRate", ExportCompressionTests.testLargeResultReducesWidthAndFrameRate),
    ("ExportCompressionTests.testReductionNeverCrossesQualityLimits", ExportCompressionTests.testReductionNeverCrossesQualityLimits),
    ("ExportCompressionTests.testMinimumConfigurationCannotReduceFurther", ExportCompressionTests.testMinimumConfigurationCannotReduceFurther),
    ("ExportCompressionTests.testMinimumWidthStillReducesFrameRate", ExportCompressionTests.testMinimumWidthStillReducesFrameRate),
    ("ExportCancellationTests.testCancellationIsIdempotent", ExportCancellationTests.testCancellationIsIdempotent),
    ("ExportCancellationTests.testCancellationAndCommitAreSerialized", ExportCancellationTests.testCancellationAndCommitAreSerialized),
    ("TrimNudgingTests.testNudgingUsesCurrentFrameDuration", TrimNudgingTests.testNudgingUsesCurrentFrameDuration),
    ("TrimNudgingTests.testNudgingCannotCrossSelectionBounds", TrimNudgingTests.testNudgingCannotCrossSelectionBounds),
    ("GIFExporterIntegrationTests.testExportsRealGIFWithExpectedFrameCount", GIFExporterIntegrationTests.testExportsRealGIFWithExpectedFrameCount),
    ("GIFExporterIntegrationTests.testImpossibleTargetReturnsHonestResult", GIFExporterIntegrationTests.testImpossibleTargetReturnsHonestResult),
    ("GIFExporterIntegrationTests.testCancelledExportLeavesNoOutput", GIFExporterIntegrationTests.testCancelledExportLeavesNoOutput),
    ("GIFExporterIntegrationTests.testFractionalDurationIncludesFinalFrame", GIFExporterIntegrationTests.testFractionalDurationIncludesFinalFrame),
    ("GIFExporterIntegrationTests.testPlaybackEffectsAreEncodedIntoGIF", GIFExporterIntegrationTests.testPlaybackEffectsAreEncodedIntoGIF),
    ("VideoLoadingTests.testClearDuringLoadDoesNotRestoreOldAsset", VideoLoadingTests.testClearDuringLoadDoesNotRestoreOldAsset),
    ("PlaybackEffectTests.testReverseUsesForwardSamplesInReverseOrder", PlaybackEffectTests.testReverseUsesForwardSamplesInReverseOrder),
    ("PlaybackEffectTests.testBoomerangDoesNotDuplicateLoopEndpoints", PlaybackEffectTests.testBoomerangDoesNotDuplicateLoopEndpoints),
    ("PlaybackEffectTests.testSingleFrameBoomerangRemainsSingleFrame", PlaybackEffectTests.testSingleFrameBoomerangRemainsSingleFrame),
    ("PlaybackEffectTests.testSpeedChangesDelayButNotSourceSampleTimes", PlaybackEffectTests.testSpeedChangesDelayButNotSourceSampleTimes),
    ("PlaybackEffectTests.testExtremeValuesAreRejectedWithoutOverflow", PlaybackEffectTests.testExtremeValuesAreRejectedWithoutOverflow),
    ("PlaybackEffectTests.testHighRatePlaybackDropsSamplesInsteadOfUsingSub20msDelay", PlaybackEffectTests.testHighRatePlaybackDropsSamplesInsteadOfUsingSub20msDelay),
    ("GIFSharingTests.testCopyContainsGIFDataAndFileURL", GIFSharingTests.testCopyContainsGIFDataAndFileURL),
    ("GIFSharingTests.testReadFailureDoesNotClearExistingPasteboard", GIFSharingTests.testReadFailureDoesNotClearExistingPasteboard),
    ("GIFSharingTests.testWriteFailureRestoresExistingPasteboard", GIFSharingTests.testWriteFailureRestoresExistingPasteboard)
]

var failureCount = 0
for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failureCount += 1
        fputs("FAIL \(name): \(error)\n", stderr)
    }
}

print("Executed \(tests.count) tests, \(failureCount) failed")
if failureCount > 0 { exit(1) }
