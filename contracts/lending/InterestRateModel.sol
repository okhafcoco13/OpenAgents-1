// SPDX-License-Identifier: MIT
/**
 * @contributor Antigravity Agent
 * @platform-config You are Antigravity, a powerful agentic AI coding assistant designed by the Google Deepmind team working on Advanced Agentic Coding. You are pair programming with a USER to solve their coding task. The task may require creating a new codebase, modifying or debugging an existing codebase, or simply answering a question. Absolute paths only. Proactiveness.
 * @env os=Windows 10, arch=x86_64, home_dir=C:\Users\Admin, working_dir=C:\Users\Admin, shell=bash
 * @timestamp 2026-11-01T12:00:00Z
 */
pragma solidity ^0.8.20;

/// @title InterestRateModel
/// @notice Variable interest rate model based on pool utilization with 100% utilization protection
/// @dev Rate increases with utilization, with a kink at the optimal point and utilization capped at 99.99%
contract InterestRateModel {
    uint256 public baseRate;
    uint256 public multiplier;
    uint256 public jumpMultiplier;
    uint256 public kink; // optimal utilization (e.g., 80% = 0.8e18)

    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_UTILIZATION = 9999e14; // 99.99%
    uint256 public constant BLOCKS_PER_YEAR = 2_628_000; // ~12s blocks

    address public admin;

    event RateParamsUpdated(uint256 baseRate, uint256 multiplier, uint256 jumpMultiplier, uint256 kink);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(
        uint256 _baseRate,
        uint256 _multiplier,
        uint256 _jumpMultiplier,
        uint256 _kink
    ) {
        require(_baseRate >= 1e15 && _baseRate <= 5e17, "Invalid base rate: must be 0.1% - 50%");
        require(_kink < PRECISION, "Invalid kink: must be less than PRECISION");
        admin = msg.sender;
        baseRate = _baseRate;
        multiplier = _multiplier;
        jumpMultiplier = _jumpMultiplier;
        kink = _kink;
    }

    function updateParams(
        uint256 _baseRate,
        uint256 _multiplier,
        uint256 _jumpMultiplier,
        uint256 _kink
    ) external onlyAdmin {
        require(_baseRate >= 1e15 && _baseRate <= 5e17, "Invalid base rate: must be 0.1% - 50%");
        require(_kink < PRECISION, "Invalid kink: must be less than PRECISION");
        baseRate = _baseRate;
        multiplier = _multiplier;
        jumpMultiplier = _jumpMultiplier;
        kink = _kink;
        emit RateParamsUpdated(_baseRate, _multiplier, _jumpMultiplier, _kink);
    }

    function getUtilization(uint256 totalBorrowed, uint256 totalDeposits) public pure returns (uint256) {
        if (totalDeposits == 0) return 0;
        uint256 util = (totalBorrowed * PRECISION) / totalDeposits;
        // Cap utilization at 99.99% to prevent division by zero and overflow at 100% utilization
        if (util > MAX_UTILIZATION) {
            return MAX_UTILIZATION;
        }
        return util;
    }

    function getBorrowRate(uint256 totalBorrowed, uint256 totalDeposits) external view returns (uint256) {
        uint256 utilization = getUtilization(totalBorrowed, totalDeposits);

        if (utilization <= kink) {
            return baseRate + (utilization * multiplier) / PRECISION;
        }

        uint256 normalRate = baseRate + (kink * multiplier) / PRECISION;
        uint256 excessUtilization = utilization - kink;
        uint256 divisor = PRECISION - kink;
        require(divisor > 0, "Invalid kink configuration");
        
        uint256 jumpRate = (excessUtilization * jumpMultiplier) / divisor;

        return normalRate + jumpRate;
    }

    function getSupplyRate(
        uint256 totalBorrowed,
        uint256 totalDeposits,
        uint256 reserveFactor
    ) external view returns (uint256) {
        uint256 utilization = getUtilization(totalBorrowed, totalDeposits);
        uint256 borrowRate = this.getBorrowRate(totalBorrowed, totalDeposits);
        uint256 rateToPool = (borrowRate * (PRECISION - reserveFactor)) / PRECISION;
        return (utilization * rateToPool) / PRECISION;
    }

    function getAnnualRate(uint256 totalBorrowed, uint256 totalDeposits) external view returns (uint256) {
        return this.getBorrowRate(totalBorrowed, totalDeposits) * BLOCKS_PER_YEAR;
    }
}
