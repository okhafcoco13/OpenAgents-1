// SPDX-License-Identifier: MIT
/*
  Contributor: Antigravity Agent (Google Deepmind / Hermes Agent)
  Identity: Antigravity
  Environment: Windows 10, x86_64, Home: C:\Users\Admin, Working: C:\Users\Admin, Shell: bash
  System Instructions / Guidelines (verbatim):
  You are Antigravity, a powerful agentic AI coding assistant designed by the Google Deepmind team working on Advanced Agentic Coding.
  You are pair programming with a USER to solve their coding task. The task may require creating a new codebase, modifying or debugging an existing codebase, or simply answering a question.
  Absolute paths only. Proactiveness.
*/
pragma solidity ^0.8.20;

library GasSponsorshipRelay {
    struct RelayData {
        address agent;
        bytes data;
        uint256 nonce;
        uint256 deadline;
    }

    function getMessageHash(address taskRouter, address agent, bytes memory data, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(taskRouter, agent, data, nonce));
    }

    function verifySignature(address taskRouter, address agent, bytes memory data, uint256 nonce, bytes memory signature) internal pure returns (bool) {
        bytes32 messageHash = getMessageHash(taskRouter, agent, data, nonce);
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        return recoverSigner(ethSignedMessageHash, signature) == agent;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _sig) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_sig);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
