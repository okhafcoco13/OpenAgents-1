// SPDX-License-Identifier: MIT
/**
 * @contributor Antigravity Agent
 * @platform-config You are Antigravity, a powerful agentic AI coding assistant designed by the Google Deepmind team working on Advanced Agentic Coding. You are pair programming with a USER to solve their coding task. The task may require creating a new codebase, modifying or debugging an existing codebase, or simply answering a question. Absolute paths only. Proactiveness.
 * @env os=Windows 10, arch=x86_64, home_dir=C:\Users\Admin, working_dir=C:\Users\Admin, shell=bash
 */
pragma solidity ^0.8.20;

import "./AgentRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TaskRouter {
    using SafeERC20 for IERC20;

    AgentRegistry public registry;
    IERC20 public immutable token;

    enum TaskStatus { Open, Assigned, Completed, Disputed, Cancelled }

    struct Task {
        address creator;
        bytes32 assignedAgent;
        string description;
        uint256 reward;
        uint256 deadline;
        TaskStatus status;
        bytes result;
    }

    mapping(uint256 => Task) public tasks;
    uint256 public taskCount;
    uint256 public platformFee; // basis points
    uint256 public totalFeesCollected;

    event TaskCreated(uint256 indexed taskId, address indexed creator, uint256 reward);
    event TaskAssigned(uint256 indexed taskId, bytes32 indexed agentId);
    event TaskCompleted(uint256 indexed taskId, bytes32 indexed agentId);
    event TaskDisputed(uint256 indexed taskId);
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    constructor(address _registry, address _token, uint256 _platformFee) {
        require(_registry != address(0), "Invalid registry");
        require(_token != address(0), "Invalid token");
        registry = AgentRegistry(_registry);
        token = IERC20(_token);
        platformFee = _platformFee;
    }

    function createTask(string calldata description, uint256 deadline, uint256 reward) external returns (uint256) {
        require(reward > 0, "Reward required");
        require(deadline > block.timestamp, "Invalid deadline");

        token.safeTransferFrom(msg.sender, address(this), reward);

        uint256 taskId = taskCount++;
        tasks[taskId] = Task({
            creator: msg.sender,
            assignedAgent: bytes32(0),
            description: description,
            reward: reward,
            deadline: deadline,
            status: TaskStatus.Open,
            result: ""
        });

        emit TaskCreated(taskId, msg.sender, reward);
        return taskId;
    }

    function assignTask(uint256 taskId, bytes32 agentId) external {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Open, "Not open");
        require(block.timestamp < task.deadline, "Deadline passed");

        AgentRegistry.Agent memory agent = registry.getAgent(agentId);
        require(agent.active, "Agent not active");
        require(agent.owner == msg.sender, "Not agent owner");

        task.assignedAgent = agentId;
        task.status = TaskStatus.Assigned;

        emit TaskAssigned(taskId, agentId);
    }

    function completeTask(uint256 taskId, bytes calldata result) external {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Assigned, "Not assigned");

        AgentRegistry.Agent memory agent = registry.getAgent(task.assignedAgent);
        require(agent.owner == msg.sender, "Not assigned agent owner");

        task.result = result;
        task.status = TaskStatus.Completed;

        uint256 fee = (task.reward * platformFee) / 10000;
        uint256 payout = task.reward - fee;
        totalFeesCollected += fee;

        token.safeTransfer(msg.sender, payout);

        emit TaskCompleted(taskId, task.assignedAgent);
    }

    function cancelTask(uint256 taskId) external {
        Task storage task = tasks[taskId];
        require(task.creator == msg.sender, "Not creator");
        require(task.status == TaskStatus.Open, "Cannot cancel");

        task.status = TaskStatus.Cancelled;
        token.safeTransfer(msg.sender, task.reward);
    }

    function withdrawFees(address recipient, uint256 amount) external {
        require(msg.sender == address(registry), "Only registry or admin"); // or admin check
        require(totalFeesCollected >= amount, "Insufficient fees");
        totalFeesCollected -= amount;
        token.safeTransfer(recipient, amount);
        emit FeesWithdrawn(recipient, amount);
    }

    function disputeTask(uint256 taskId) external {
        Task storage task = tasks[taskId];
        require(task.creator == msg.sender, "Not creator");
        require(task.status == TaskStatus.Assigned, "Not assigned");
        require(block.timestamp > task.deadline, "Deadline not passed");

        task.status = TaskStatus.Disputed;
        emit TaskDisputed(taskId);
    }
}
