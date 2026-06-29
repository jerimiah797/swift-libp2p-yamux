//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-libp2p open source project
//
// Copyright (c) 2022-2025 swift-libp2p project authors
// Licensed under MIT
//
// See LICENSE for license information
// See CONTRIBUTORS for the list of swift-libp2p project authors
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import Testing

@testable import LibP2PYAMUX

/// Regression coverage for tolerating a **redundant inbound FIN**.
///
/// A canonical libp2p peer (rust-libp2p) can send a second close frame for a
/// stream we've already seen close on: a `request_response` responder's
/// `write_response` calls `io.close()` (FIN #1), then the behaviour drops the
/// still-open inbound half (FIN #2). Before the fix, the second close reached
/// `ChildChannelStateMachine.receiveChannelClose` in `.closedRemotely`, which
/// threw `protocolViolation("Received close on closed channel")`,
/// `errorEncountered` tore the stream down, and an in-flight request whose
/// RESPONSE bytes had already arrived failed. (Caught live in the swift↔rust
/// genesis-fetch interop probe; the box logged "genesis response fully sent"
/// while the swift client got nothing.)
///
/// The fix guards `ChildChannel.handleInboundChannelClose` with
/// ``ChildChannelStateMachine/hasReceivedClose`` and ignores the duplicate
/// instead of driving the throwing state-machine transition. These tests pin
/// the predicate the guard keys on and the exact double-close condition it now
/// absorbs. End-to-end tolerance (a real rust responder sending two FINs) is
/// covered out-of-band by the burrows `RustHalfCloseProbeTests` interop probe.
@Suite("Redundant inbound close tolerance")
struct RedundantCloseToleranceTests {

    /// `hasReceivedClose` is true exactly in the states where the remote's write
    /// side is (or was) closed — `.closedRemotely` and `.closed` — and false
    /// everywhere else. This is the predicate the half-close guard depends on.
    @Test("hasReceivedClose tracks remote-close states")
    func predicateTracksRemoteCloseStates() throws {
        // Fresh, locally-opened stream: nothing received yet.
        var sm = ChildChannelStateMachine(localChannelID: 1)
        #expect(sm.hasReceivedClose == false)

        sm.sendChannelOpen(.init(senderChannel: 1, initialWindowSize: 256, maximumPacketSize: 256))
        #expect(sm.hasReceivedClose == false)  // .requestedLocally

        try sm.receiveChannelOpenConfirmation(
            .init(recipientChannel: 1, senderChannel: 1, initialWindowSize: 256, maximumPacketSize: 256))
        #expect(sm.hasReceivedClose == false)  // .active

        // Remote half-closes (sends its FIN) — our write side stays open.
        try sm.receiveChannelClose(.init(recipientChannel: 1))
        #expect(sm.hasReceivedClose == true)  // .closedRemotely
    }

    /// The bug itself: once we're `.closedRemotely`, a SECOND inbound close is a
    /// fatal `protocolViolation` at the state-machine layer — which is exactly
    /// why `handleInboundChannelClose` must short-circuit on `hasReceivedClose`
    /// BEFORE calling `receiveChannelClose`. If this throw ever stops firing the
    /// guard could be silently dropped without notice, so we pin it here.
    @Test("A second inbound close in .closedRemotely is a protocol violation the guard must absorb")
    func secondCloseInClosedRemotelyThrows() throws {
        var sm = ChildChannelStateMachine(localChannelID: 1)
        sm.sendChannelOpen(.init(senderChannel: 1, initialWindowSize: 256, maximumPacketSize: 256))
        try sm.receiveChannelOpenConfirmation(
            .init(recipientChannel: 1, senderChannel: 1, initialWindowSize: 256, maximumPacketSize: 256))
        try sm.receiveChannelClose(.init(recipientChannel: 1))  // FIN #1 → .closedRemotely
        #expect(sm.hasReceivedClose == true)

        // FIN #2 — without the handler guard this is the crash that failed the
        // genesis fetch. The guard checks `hasReceivedClose` and never reaches here.
        #expect(throws: YAMUX.Error.self) {
            try sm.receiveChannelClose(.init(recipientChannel: 1))
        }
    }
}
