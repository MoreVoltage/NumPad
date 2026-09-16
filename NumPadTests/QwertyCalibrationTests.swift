import XCTest
@testable import NumPad

final class QwertyCalibrationTests: XCTestCase {
    private func manifest(context: String = "phone:portrait:390x250") -> QwertyCalibrationManifest {
        .make(options: QwertyLayoutOptions(), topStrip: .numbers, contextID: context)
    }

    private func session() -> QwertyCalibrationSession {
        let manifest = manifest()
        var session = QwertyCalibrationSession(manifest: manifest)
        for page in [QwertyCalibrationPage.letters] {
            let rows = [QwertyRow(keys: QwertyTopStrip.keys(for: .numbers))]
                + QwertyLayout.rows(layer: page.layer, options: QwertyLayoutOptions())
            var frames: [CGRect] = []
            for (r, row) in rows.enumerated() {
                var x = CGFloat(row.leadingMargin * 40)
                for key in row.keys {
                    frames.append(CGRect(x: x + 2, y: CGFloat(r * 50 + 2), width: CGFloat(key.width * 40 - 4), height: 46))
                    x += CGFloat(key.width * 40)
                }
            }
            XCTAssertTrue(session.recordGeometry(page: page, frames: frames,
                                                 bounds: CGRect(x: 0, y: 0, width: 400, height: 250)))
        }
        return session
    }

    private func evidence(for exercise: QwertyCalibrationExercise, in session: QwertyCalibrationSession,
                          dx: Double = 0) -> [QwertyCalibrationSample] {
        exercise.expectedEntryIDs.map { id in
            let entry = session.manifest.entry(id: id)!
            let frame = session.geometry[entry.page.rawValue]!.frames[entry.buttonIndex]
            let source: QwertyCalibrationSample.Source
            switch entry.kind {
            case .character: source = exercise.isNatural ? .naturalTap : .guidedTap
            case .alternate: source = .alternate
            case .control: source = exercise.isNatural ? .naturalTap : .control
            case .behavior: source = .behavior
            }
            return .init(entryID: id, touchID: UUID().uuidString,
                         x: Double(frame.midX) + Double(frame.width) * (entry.kind == .character ? dx : 0), y: Double(frame.midY),
                         keyMidX: Double(frame.midX), keyMidY: Double(frame.midY),
                         keyWidth: Double(frame.width), keyHeight: Double(frame.height),
                         timestamp: 1, source: source)
        }
    }

    private func acceptNext(_ session: inout QwertyCalibrationSession) {
        let exercise = session.nextExercise!
        let samples = evidence(for: exercise, in: session)
        let output = exercise.expectedEntryIDs.map { session.manifest.entry(id: $0)!.output }
        XCTAssertTrue(session.recordConfirmedExercise(exerciseID: exercise.id, samples: samples,
                                                       observedOutputs: output, userConfirmed: true))
    }

    func testManifestIsGeneratedFromEveryPageIncludingStripControlsAndAlternates() {
        let manifest = manifest()
        XCTAssertEqual(Set(manifest.entries.map(\.id)).count, manifest.entries.count)
        for page in QwertyCalibrationPage.allCases {
            let expected = QwertyTopStrip.keys(for: .numbers).count
                + QwertyLayout.rows(layer: page.layer, options: QwertyLayoutOptions()).flatMap(\.keys).count
            XCTAssertEqual(manifest.entries.filter { $0.page == page && $0.parentID == nil }.count, expected)
        }
        XCTAssertTrue(manifest.entries.contains { $0.page == .uppercase && $0.output == "Z" })
        XCTAssertTrue(manifest.entries.contains { $0.page == .letters && $0.output == "cursorHold" })
        XCTAssertTrue(manifest.entries.contains { $0.kind == .alternate && $0.output == "à" })
        let ones = manifest.entries.filter { $0.page == .symbols && $0.output == "1" && $0.parentID == nil }
        XCTAssertEqual(ones.count, 2, "Strip 1 and symbol-page 1 are distinct physical keys")
        XCTAssertNotEqual(ones[0].id, ones[1].id)
        XCTAssertNotEqual(manifest.layoutFingerprint, self.manifest(context: "landscape").layoutFingerprint)
        XCTAssertEqual(manifest, self.manifest())
    }

    func testChangedLayoutAndStripProduceNewFingerprintAndInventory() {
        var options = QwertyLayoutOptions(); options.needsDismissKey = true
        let changed = QwertyCalibrationManifest.make(options: options, topStrip: .pack([.literal("hello")]),
                                                     contextID: manifest().contextID)
        XCTAssertNotEqual(changed.layoutFingerprint, manifest().layoutFingerprint)
        XCTAssertTrue(changed.entries.contains { $0.output == "dismiss" })
        XCTAssertTrue(changed.entries.contains { $0.row == 0 && $0.output == "hello" })
    }

    func testMissingOrRepeatedTouchesRejectSentenceWithoutShiftingLabels() {
        var session = session()
        let exercise = session.nextExercise!
        var samples = evidence(for: exercise, in: session)
        let output = exercise.expectedEntryIDs.map { session.manifest.entry(id: $0)!.output }
        samples.removeFirst()
        XCTAssertFalse(session.recordConfirmedExercise(exerciseID: exercise.id, samples: samples,
                                                        observedOutputs: output, userConfirmed: true))
        XCTAssertTrue(session.coverage.isEmpty)
        samples = evidence(for: exercise, in: session)
        samples[1] = samples[0]
        XCTAssertFalse(session.recordConfirmedExercise(exerciseID: exercise.id, samples: samples,
                                                        observedOutputs: output, userConfirmed: true))
        XCTAssertTrue(session.samples.isEmpty)
    }

    func testUnconfirmedSamplesCannotTrainAndSkippingNeverGrantsCoverage() {
        var session = session()
        let exercise = session.nextExercise!
        let samples = evidence(for: exercise, in: session)
        let output = exercise.expectedEntryIDs.map { session.manifest.entry(id: $0)!.output }
        XCTAssertFalse(session.recordConfirmedExercise(exerciseID: exercise.id, samples: samples,
                                                        observedOutputs: output, userConfirmed: false))
        session.skipNaturalExercise()
        XCTAssertFalse(session.hasFullCoverage)
        XCTAssertEqual(session.coveredKeyCount, 0)
    }

    func testGeometryMismatchRequiresNewSession() {
        var session = session()
        let geometry = session.geometry[QwertyCalibrationPage.letters.rawValue]!
        var frames = geometry.frames
        frames[0].origin.x += 1
        XCTAssertFalse(session.recordGeometry(page: .letters, frames: frames, bounds: geometry.bounds))
    }

    func testThreeNaturalSentencesCoverAlphabetWithNoExtraDrills() throws {
        var session = session()
        XCTAssertEqual(QwertyCalibrationManifest.version, 3)
        XCTAssertEqual(session.requiredKeyCount, 26)
        XCTAssertEqual(Set(session.manifest.requiredEntries.map(\.output)), Set("abcdefghijklmnopqrstuvwxyz".map(String.init)))
        XCTAssertTrue(session.manifest.entries.filter { !session.manifest.requiredEntries.contains($0) }
            .allSatisfy { $0.minimumSamples == 0 }, "No strip, uppercase, alternate or gesture drills")
        let first = try XCTUnwrap(session.nextExercise)
        XCTAssertTrue(first.isNatural)
        XCTAssertFalse(first.isValidation)
        XCTAssertEqual(first.text, "the quick brown fox jumps over the lazy dog")
        XCTAssertEqual(first.expectedEntryIDs.count, 43)
        acceptNext(&session)
        XCTAssertEqual(session.coveredKeyCount, 26)
        XCTAssertTrue(session.hasFullCoverage)
        XCTAssertFalse(session.isComplete, "Alphabet coverage alone does not complete the three-sentence run")
        XCTAssertNil(QwertyCalibrationTrainer.finish(session: session, previous: nil))
        let checkpoint = try JSONEncoder().encode(session)
        let resumed = try JSONDecoder().decode(QwertyCalibrationSession.self, from: checkpoint)
        XCTAssertEqual(session, resumed)
        XCTAssertEqual(session.nextExercise, resumed.nextExercise)
        let second = try XCTUnwrap(session.nextExercise)
        XCTAssertTrue(second.isNatural)
        XCTAssertFalse(second.isValidation)
        XCTAssertEqual(second.text, "please bring five dozen mugs")
        XCTAssertEqual(second.expectedEntryIDs.count, 28)
        acceptNext(&session)
        let training = session.samples
        let validation = try XCTUnwrap(session.nextExercise)
        XCTAssertTrue(validation.isNatural)
        XCTAssertTrue(validation.isValidation)
        XCTAssertEqual(validation.text, "we enjoy quiet walks")
        XCTAssertEqual(validation.expectedEntryIDs.count, 20)
        acceptNext(&session)
        XCTAssertTrue(session.isComplete)
        XCTAssertNil(session.nextExercise)
        XCTAssertEqual(session.completedExerciseIDs.count, 3)
        XCTAssertEqual(session.samples, training, "Held-out touches must never train")
        XCTAssertEqual(session.samples.count, 71)
        XCTAssertEqual(session.validationSamples.count, 20)
        XCTAssertEqual(session.samples.filter { session.manifest.entry(id: $0.entryID)?.output == " " }.count, 12)
        XCTAssertEqual(session.validationSamples.filter { session.manifest.entry(id: $0.entryID)?.output == " " }.count, 3)
        XCTAssertTrue(Set(session.samples.map(\.touchID)).isDisjoint(with: session.validationSamples.map(\.touchID)))
        XCTAssertEqual(session.samples.count + session.validationSamples.count, 91)
        let run = try XCTUnwrap(QwertyCalibrationTrainer.finish(session: session, previous: nil))
        XCTAssertEqual(run.validation.sampleCount, 17, "Spaces are saved but excluded from letter-routing validation")
        XCTAssertEqual(run.validation.distinctKeys, 14)
        XCTAssertEqual(run.validation.policyVersion, 3)
        XCTAssertEqual(run.validation.baselineErrors, 0)
        XCTAssertEqual(run.validation.candidateErrors, 0)
        XCTAssertFalse(run.validation.shouldActivate, "Ties keep the previous/default profile")
        XCTAssertTrue(run.hasFullCoverage)
        XCTAssertEqual(Set(run.profile.offsets.keys), Set(session.manifest.requiredEntries.map(\.id)))
        XCTAssertTrue(run.profile.offsets.values.allSatisfy { $0.count == 59 }, "Only training letter taps fit the shared bias")
        XCTAssertEqual(session.geometry.count, 1)
    }

    func testNaturalAlignmentAcceptsCaseAndUniqueSubstitutionsButRejectsAmbiguity() {
        func accepts(_ expected: String, _ observed: String) -> Bool {
            QwertyCalibrationAligner.isUnambiguous(expected: expected.map(String.init),
                observed: observed.map(String.init), touchCount: observed.count)
        }
        XCTAssertTrue(accepts("the quick brown fox", "The quick brown fox"))
        XCTAssertTrue(accepts("the quick brown fox", "the quock brown fox"))
        XCTAssertFalse(accepts("the quick", "the quiick"), "Insertions cannot shift labels")
        XCTAssertFalse(accepts("the quick", "the quik"), "Omissions cannot shift labels")
        XCTAssertFalse(accepts("the quick", "hte quick"), "Transpositions have ambiguous optimal alignments")
        XCTAssertFalse(accepts("aba", "bab"), "A repeated-position shift cannot become three training labels")
        XCTAssertFalse(accepts("a cat", "ac at"), "Word boundaries must match")
        XCTAssertFalse(accepts("cat", "ca!"), "Observed output must be a physical letter")
        XCTAssertFalse(accepts("cat", "cát"))
    }

    func testNearbyRawSubstitutionCanTrainAfterExplicitSentenceConfirmation() throws {
        var session = session()
        let exercise = try XCTUnwrap(session.nextExercise)
        let samples = evidence(for: exercise, in: session, dx: 0.6)
        var outputs = exercise.text.map(String.init)
        outputs[0] = "Y" // The prompted t can route to its adjacent y.
        XCTAssertTrue(session.recordConfirmedExercise(exerciseID: exercise.id, samples: samples,
            observedOutputs: outputs, userConfirmed: true))
        XCTAssertEqual(session.samples.first?.entryID, exercise.expectedEntryIDs.first)
        XCTAssertEqual(session.samples.count, 43)
    }

    func testCandidateEvaluationUsesSameViewSpaceOffsetsAsRuntime() throws {
        var session = session()
        for _ in 0..<3 {
            let exercise = try XCTUnwrap(session.nextExercise)
            // Prompted letter identity is independent of which neighboring key was routed.
            let samples = evidence(for: exercise, in: session, dx: exercise.isValidation ? 0.60 : 0.65)
            let output = exercise.expectedEntryIDs.map { session.manifest.entry(id: $0)!.output }
            XCTAssertTrue(session.recordConfirmedExercise(exerciseID: exercise.id, samples: samples,
                                                           observedOutputs: output, userConfirmed: true))
        }
        let run = try XCTUnwrap(QwertyCalibrationTrainer.finish(session: session, previous: nil))
        XCTAssertGreaterThanOrEqual(run.validation.baselineErrors, 2)
        XCTAssertEqual(run.validation.candidateErrors, 0)
        XCTAssertTrue(run.validation.shouldActivate)
        XCTAssertTrue(run.profile.offsets.values.allSatisfy { $0.dx == 0.3 && $0.dy == 0 && $0.count == 59 })
        let geometry = session.geometry[QwertyCalibrationPage.letters.rawValue]!
        let offsets = run.profile.indexedOffsets(manifest: session.manifest, page: .letters, frames: geometry.frames)
        let entry = try XCTUnwrap(session.manifest.requiredEntries.first { $0.output == "q" })
        let offset = try XCTUnwrap(run.profile.offsets[entry.id])
        XCTAssertEqual(offsets[entry.buttonIndex]!.dx, CGFloat(offset.dx) * geometry.frames[entry.buttonIndex].width,
                       accuracy: 0.0001, "The resolver accepts points, not normalized fractions")
    }

    func testPooledBiasUsesOnlyTrainingAndRegularizesAllLettersTogether() throws {
        var session = session()
        for _ in 0..<3 {
            let exercise = try XCTUnwrap(session.nextExercise)
            let samples = evidence(for: exercise, in: session, dx: exercise.isValidation ? -0.6 : 0.2)
            let output = exercise.expectedEntryIDs.map { session.manifest.entry(id: $0)!.output }
            XCTAssertTrue(session.recordConfirmedExercise(exerciseID: exercise.id, samples: samples,
                observedOutputs: output, userConfirmed: true))
        }
        let run = try XCTUnwrap(QwertyCalibrationTrainer.finish(session: session, previous: nil))
        XCTAssertEqual(run.profile.offsets.count, 26)
        for offset in run.profile.offsets.values {
            XCTAssertEqual(offset.dx, 59 * 0.2 / 71, accuracy: 0.000001)
            XCTAssertEqual(offset.dy, 0)
            XCTAssertEqual(offset.count, 59)
        }
        XCTAssertFalse(run.validation.shouldActivate, "Opposing held-out evidence must not activate the learned bias")
    }

    func testSentenceActivationRequiresIndependentChecksTwoRecoveriesAndLowErrorRate() {
        func validation(_ count: Int = 17, distinct: Int = 14, baseline: Int = 6,
                        previous: Int = 6, candidate: Int = 4, controls: Int = 0) -> QwertyCalibrationValidation {
            .init(sampleCount: count, distinctKeys: distinct, baselineErrors: baseline,
                  previousErrors: previous, candidateErrors: candidate,
                  protectedControlFailures: controls, policyVersion: 3)
        }
        XCTAssertFalse(validation(16).shouldActivate)
        XCTAssertFalse(validation(distinct: 13).shouldActivate)
        XCTAssertFalse(validation(baseline: 5).shouldActivate)
        XCTAssertFalse(validation(previous: 5).shouldActivate)
        XCTAssertFalse(validation(baseline: 7, previous: 7, candidate: 5).shouldActivate, "Five of 17 errors exceeds 25 percent")
        XCTAssertFalse(validation(candidate: -1).shouldActivate)
        XCTAssertFalse(validation(controls: 1).shouldActivate)
        XCTAssertTrue(validation().shouldActivate)
        XCTAssertTrue(validation(baseline: 2, previous: 2, candidate: 0).shouldActivate)
    }

    func testQuickActivationRequiresFourDistinctChecksTwoRecoveriesAndZeroErrors() {
        func validation(_ count: Int = 4, distinct: Int = 4, baseline: Int = 2,
                        previous: Int = 2, candidate: Int = 0, controls: Int = 0) -> QwertyCalibrationValidation {
            .init(sampleCount: count, distinctKeys: distinct, baselineErrors: baseline,
                  previousErrors: previous, candidateErrors: candidate,
                  protectedControlFailures: controls, policyVersion: 2)
        }
        XCTAssertFalse(validation(3, distinct: 3).shouldActivate)
        XCTAssertFalse(validation(distinct: 3).shouldActivate)
        XCTAssertFalse(validation(baseline: 1).shouldActivate)
        XCTAssertFalse(validation(previous: 1).shouldActivate)
        XCTAssertFalse(validation(baseline: 0, previous: 0).shouldActivate)
        XCTAssertFalse(validation(candidate: 1).shouldActivate)
        XCTAssertFalse(validation(previous: 0, candidate: 1).shouldActivate)
        XCTAssertFalse(validation(controls: 1).shouldActivate)
        XCTAssertTrue(validation().shouldActivate)
    }

    func testLegacyValidationRemainsDecodableAndUsesOriginalPolicy() throws {
        let legacy = QwertyCalibrationValidation(sampleCount: 78, distinctKeys: 26,
            baselineErrors: 10, previousErrors: 10, candidateErrors: 3, protectedControlFailures: 0)
        XCTAssertTrue(legacy.shouldActivate)
        let data = try JSONEncoder().encode(legacy)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("policyVersion"))
        let decoded = try JSONDecoder().decode(QwertyCalibrationValidation.self, from: data)
        XCTAssertEqual(decoded, legacy)
        XCTAssertTrue(decoded.shouldActivate)
        var future = legacy
        future.policyVersion = 99
        XCTAssertFalse(future.shouldActivate)
    }

    func testResetRejectsAQueuedOldCheckpointAndReadOnlyStoreCannotWrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = QwertyCalibrationStore(directoryURL: directory, writable: true)
        let session = session()
        let saved = expectation(description: "checkpoint")
        store.checkpoint(session, expectedGeneration: 0) { result in
            if case .failure(let error) = result { XCTFail("Persistence failed: \(error)") }; saved.fulfill()
        }
        wait(for: [saved], timeout: 5)
        let reset = expectation(description: "reset")
        store.reset { result in if case .failure(let error) = result { XCTFail("Persistence failed: \(error)") }; reset.fulfill() }
        wait(for: [reset], timeout: 5)
        let stale = expectation(description: "stale")
        store.checkpoint(session, expectedGeneration: 0) { result in
            guard case .failure = result else { XCTFail("Old generation resurrected"); stale.fulfill(); return }
            stale.fulfill()
        }
        wait(for: [stale], timeout: 5)
        XCTAssertTrue(store.load().sessions.isEmpty)
        let denied = expectation(description: "read only")
        QwertyCalibrationStore(directoryURL: directory, writable: false).checkpoint(session, expectedGeneration: 1) { result in
            guard case .failure = result else { XCTFail("Extension wrote shared file"); denied.fulfill(); return }
            denied.fulfill()
        }
        wait(for: [denied], timeout: 5)
    }
    func testCorruptAndFutureFilesFailClosedInsteadOfActivatingOrOverwriting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("qwerty-tap-calibration-v1.json")
        let store = QwertyCalibrationStore(directoryURL: directory, writable: true)
        try Data("{broken".utf8).write(to: file, options: .atomic)
        XCTAssertTrue(store.load().activeProfiles.isEmpty)
        let denied = expectation(description: "corrupt write denied")
        store.checkpoint(session(), expectedGeneration: 0) { result in
            guard case .failure = result else { XCTFail("Corrupt data overwritten implicitly"); denied.fulfill(); return }
            denied.fulfill()
        }
        wait(for: [denied], timeout: 5)
        let future = Data("{\"version\":99}".utf8)
        try future.write(to: file, options: .atomic)
        XCTAssertTrue(store.load().activeProfiles.isEmpty)
        let reset = expectation(description: "future downgrade denied")
        store.reset { result in
            guard case .failure = result else { XCTFail("Future schema downgraded"); reset.fulfill(); return }
            reset.fulfill()
        }
        wait(for: [reset], timeout: 5)
        XCTAssertEqual(try Data(contentsOf: file), future)
    }

    func testActiveProjectionIsBoundedExcludesTracesAndPromotesRestoredProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = QwertyCalibrationStore(directoryURL: directory, writable: true)
        var runs: [QwertyCalibrationRun] = []
        for index in 0..<17 {
            let manifest = self.manifest(context: "layout-\(index)")
            let date = Date(timeIntervalSince1970: Double(index))
            let profile = QwertyCalibrationProfile(id: UUID(), layoutFingerprint: manifest.layoutFingerprint,
                createdAt: date, parentID: nil, offsets: ["letters:1:0": .init(dx: 0.1, dy: 0, count: 5)])
            let run = QwertyCalibrationRun(id: UUID(), completedAt: date, manifest: manifest,
                coverage: Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.id, $0.minimumSamples) }),
                profile: profile, validation: .init(sampleCount: 78, distinctKeys: 26, baselineErrors: 5,
                    previousErrors: 5, candidateErrors: 1, protectedControlFailures: 0), rejectedExercises: 0)
            let saved = expectation(description: "save layout \(index)")
            store.saveRun(run, expectedGeneration: 0) { result in
                if case .failure(let error) = result { XCTFail("Persistence failed: \(error)") }; saved.fulfill()
            }
            wait(for: [saved], timeout: 5)
            runs.append(run)
        }
        let oldest = runs[0]
        XCTAssertEqual(store.loadActiveProfiles().count, 16)
        XCTAssertNil(store.loadActiveProfiles()[oldest.manifest.layoutFingerprint])
        XCTAssertEqual(store.load().runs.count, 17, "Projection cap must not prune saved history")
        let restored = expectation(description: "restore oldest")
        store.restore(profileID: oldest.profile.id, layoutFingerprint: oldest.manifest.layoutFingerprint,
                      expectedGeneration: 0) { result in
            if case .failure(let error) = result { XCTFail("Persistence failed: \(error)") }; restored.fulfill()
        }
        wait(for: [restored], timeout: 5)
        XCTAssertEqual(store.loadActiveProfiles()[oldest.manifest.layoutFingerprint], oldest.profile)
        XCTAssertEqual(store.loadActiveProfiles().count, 16)

        var partial = session()
        acceptNext(&partial)
        let checkpoint = expectation(description: "raw checkpoint")
        store.checkpoint(partial, expectedGeneration: 1) { result in
            if case .failure(let error) = result { XCTFail("Persistence failed: \(error)") }; checkpoint.fulfill()
        }
        wait(for: [checkpoint], timeout: 5)
        let projectionURL = directory.appendingPathComponent("qwerty-tap-active-v1.json")
        let projectionData = try Data(contentsOf: projectionURL)
        let projection = try XCTUnwrap(JSONSerialization.jsonObject(with: projectionData) as? [String: Any])
        XCTAssertNil(projection["sessions"])
        XCTAssertNil(projection["runs"])
        XCTAssertFalse(String(decoding: projectionData, as: UTF8.self).contains(partial.samples[0].touchID))
        XCTAssertLessThan(projectionData.count, 512 * 1_024)
        XCTAssertEqual(store.loadActiveProfiles()[oldest.manifest.layoutFingerprint], oldest.profile,
                       "A routine checkpoint must retain restore priority")

        let envelopeURL = directory.appendingPathComponent("qwerty-tap-calibration-v1.json")
        let oldEnvelope = try Data(contentsOf: envelopeURL)
        let reset = expectation(description: "clear projection")
        store.reset { result in if case .failure(let error) = result { XCTFail("Persistence failed: \(error)") }; reset.fulfill() }
        wait(for: [reset], timeout: 5)
        XCTAssertTrue(store.loadActiveProfiles().isEmpty)
        // Simulates the old envelope remaining after the reset's projection commits but its
        // full-envelope write fails. The projection tombstone must prevent resurrection.
        try oldEnvelope.write(to: envelopeURL, options: .atomic)
        XCTAssertTrue(store.load().activeProfiles.isEmpty)
        XCTAssertTrue(store.load().runs.isEmpty)
        XCTAssertTrue(store.load().sessions.isEmpty)
        XCTAssertEqual(store.load().generation, 2)
    }

    func testProjectionRejectsOversizedAndFutureDataWithoutReadingHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = QwertyCalibrationStore(directoryURL: directory, writable: false)
        let projection = directory.appendingPathComponent("qwerty-tap-active-v1.json")
        try Data(repeating: 32, count: 512 * 1_024 + 1).write(to: projection)
        XCTAssertTrue(store.loadActiveProfiles().isEmpty)
        try Data("{\"version\":99}".utf8).write(to: projection, options: .atomic)
        XCTAssertTrue(store.loadActiveProfiles().isEmpty)
        try Data("{broken".utf8).write(to: projection, options: .atomic)
        XCTAssertTrue(store.loadActiveProfiles().isEmpty)
    }

}
