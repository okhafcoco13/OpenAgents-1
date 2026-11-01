// SPDX-License-Identifier: MIT
/**
 * @contributor Antigravity Agent
 * @platform-config You are Antigravity, a powerful agentic AI coding assistant designed by the Google Deepmind team working on Advanced Agentic Coding. You are pair programming with a USER to solve their coding task. The task may require creating a new codebase, modifying or debugging an existing codebase, or simply answering a question. Absolute paths only. Proactiveness.
 * @env os=Windows 10, arch=x86_64, home_dir=C:\Users\Admin, working_dir=C:\Users\Admin, shell=bash
 * @timestamp 2026-11-01T12:00:00Z
 */
pragma solidity ^0.8.20;

/// @title Timelock
/// @notice Time-delayed execution controller for governance actions with grace period enforcement
/// @dev Queued transactions must wait a minimum delay and be executed within the GRACE_PERIOD window
contract Timelock {
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    event NewAdmin(address indexed newAdmin);
    event NewDelay(uint256 indexed newDelay);
    event QueueTransaction(bytes32 indexed txHash, address target, uint256 value, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address target, uint256 value, bytes data, uint256 eta);
    event CancelTransaction(bytes32 indexed txHash, address target, uint256 value, bytes data, uint256 eta);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not admin");
        _;
    }

    constructor(address _admin, uint256 _delay) {
        require(_delay <= MAXIMUM_DELAY, "Timelock: delay exceeds max");
        admin = _admin;
        delay = _delay;
    }

    function setDelay(uint256 _delay) external onlyAdmin {
        require(_delay <= MAXIMUM_DELAY, "Timelock: delay exceeds max");
        delay = _delay;
        emit NewDelay(_delay);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: not pending admin");
        admin = msg.sender;
        pendingAdmin = address(0);
        emit NewAdmin(msg.sender);
    }

    function setPendingAdmin(address _pendingAdmin) external onlyAdmin {
        pendingAdmin = _pendingAdmin;
    }

    function queueTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external onlyAdmin returns (bytes32 txHash) {
        require(eta >= block.timestamp + delay, "Timelock: estimated execution block must satisfy delay");
        txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        require(queuedTransactions[txHash], "Timelock: tx not queued");
        require(block.timestamp >= eta, "Timelock: eta not reached");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: tx stale");

        queuedTransactions[txHash] = false;
        (bool ok, bytes memory result) = target.call{value: value}(data);
        require(ok, "Timelock: tx reverted");

        emit ExecuteTransaction(txHash, target, value, data, eta);
        return result;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        require(queuedTransactions[txHash], "Timelock: tx not queued");
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, data, eta);
    }

    receive() external payable {}
}
