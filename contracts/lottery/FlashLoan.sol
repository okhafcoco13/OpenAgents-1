// SPDX-License-Identifier: MIT
/**
 * @contributor-info
 * Identity: Antigravity Agent (Google Deepmind / Hermes Agent)
 * Session Context (verbatim):
 * You are Antigravity, a powerful agentic AI coding assistant designed by the Google Deepmind team working on Advanced Agentic Coding.
 * You are pair programming with a USER to solve their coding task. The task may require creating a new codebase, modifying or debugging an existing codebase, or simply answering a question.
 * Absolute paths only. Proactiveness.
 * OS: Windows 10
 * Architecture: x86_64
 * Home Directory: C:\Users\Admin
 * Working Directory: C:\Users\Admin
 * Shell: bash
 */
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bool);
}

contract FlashLoan is ReentrancyGuard, Ownable {
    IERC20 public immutable token;
    uint256 public feeBps; // fee in basis points
    bool public paused;

    event FlashLoanExecuted(address indexed receiver, uint256 amount, uint256 fee);
    event PausedStateChanged(bool isPaused);

    constructor(address _token, uint256 _feeBps) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token");
        token = IERC20(_token);
        feeBps = _feeBps;
    }

    modifier whenNotPaused() {
        require(!paused, "FlashLoan: paused");
        _;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function flashLoan(
        address receiver,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant whenNotPaused returns (bool) {
        uint256 balanceBefore = token.balanceOf(address(this));
        
        // Max loan cap: 50% of pool balance
        require(amount <= balanceBefore / 2, "FlashLoan: loan amount exceeds 50% of pool");
        require(amount > 0, "FlashLoan: invalid loan amount");

        // Fee calculation with minimum fee of 1 token and rebasing safety
        uint256 calculatedFee = (amount * feeBps) / 10000;
        uint256 fee = calculatedFee > 0 ? calculatedFee : 1;

        require(token.transfer(receiver, amount), "FlashLoan: transfer failed");

        require(
            IFlashLoanReceiver(receiver).executeOperation(address(token), amount, fee, data),
            "FlashLoan: receiver execution failed"
        );

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "FlashLoan: insufficient repayment with fee");

        emit FlashLoanExecuted(receiver, amount, fee);
        return true;
    }
}
