// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentRegistry
/// @notice Holder-curated registry of Agent ID ecosystem projects.
/// @dev Only Agent ID holders can submit projects and signal. One Agent ID
///      equals one signal per project, so curation is sybil-resistant:
///      Agent ID is non-transferable and limited to one per user.
///      The contract holds no funds and has NO owner powers: no mint,
///      no pause, no tax, no freeze, no withdrawal, no upgrade.
///      Listing rules: one entry per contract address, and the submitted
///      address must contain deployed code (plain wallets rejected).
///      Flag reasons (recorded in the Signaled event, not in storage):
///      0 = none (upvotes only), 1 = farm, 2 = scam, 3 = dead/abandoned.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentRegistry {
    IAgentID public immutable agentId;

    struct Project {
        string name;
        address projectContract;
        string category;
        string description;
        string website;
        string xHandle;
        address submitter;
        uint256 upvotes;
        uint256 flags;
        uint256 createdAt;
        bool exists;
    }

    Project[] private _projects;
    mapping(uint256 => mapping(address => bool)) public hasSignaled;
    mapping(address => bool) public isListed;

    event ProjectSubmitted(uint256 indexed projectId, address indexed submitter, string name, address projectContract);
    event Signaled(uint256 indexed projectId, address indexed voter, bool flagged, uint8 reason);

    constructor(address agentId_) {
        require(agentId_ != address(0), "zero agent id");
        agentId = IAgentID(agentId_);
    }

    modifier onlyAgentHolder() {
        require(agentId.balanceOf(msg.sender) > 0, "Agent ID required");
        _;
    }

    function submitProject(
        string calldata name,
        address projectContract,
        string calldata category,
        string calldata description,
        string calldata website,
        string calldata xHandle
    ) external onlyAgentHolder returns (uint256 projectId) {
        require(bytes(name).length > 0 && bytes(name).length <= 60, "bad name");
        require(projectContract != address(0), "zero contract");
        require(projectContract.code.length > 0, "not a contract");
        require(!isListed[projectContract], "already listed");
        require(bytes(category).length > 0 && bytes(category).length <= 24, "bad category");
        require(bytes(description).length <= 200, "description too long");
        require(bytes(website).length <= 120, "website too long");
        require(bytes(xHandle).length <= 40, "x too long");
        projectId = _projects.length;
        Project storage p = _projects.push();
        p.name = name;
        p.projectContract = projectContract;
        p.category = category;
        p.description = description;
        p.website = website;
        p.xHandle = xHandle;
        p.submitter = msg.sender;
        p.createdAt = block.timestamp;
        p.exists = true;
        isListed[projectContract] = true;
        emit ProjectSubmitted(projectId, msg.sender, name, projectContract);
    }

    function signal(uint256 projectId, bool flagged, uint8 reason) external onlyAgentHolder {
        require(projectId < _projects.length, "no project");
        require(!hasSignaled[projectId][msg.sender], "already signaled");
        require(reason <= 3, "bad reason");
        require(flagged == (reason > 0), "reason mismatch");
        hasSignaled[projectId][msg.sender] = true;
        if (flagged) {
            _projects[projectId].flags += 1;
        } else {
            _projects[projectId].upvotes += 1;
        }
        emit Signaled(projectId, msg.sender, flagged, reason);
    }

    function getProject(
        uint256 projectId
    )
        external
        view
        returns (
            string memory name,
            address projectContract,
            string memory category,
            string memory description,
            string memory website,
            string memory xHandle,
            address submitter,
            uint256 upvotes,
            uint256 flags,
            uint256 createdAt
        )
    {
        require(projectId < _projects.length, "no project");
        Project storage p = _projects[projectId];
        return (
            p.name,
            p.projectContract,
            p.category,
            p.description,
            p.website,
            p.xHandle,
            p.submitter,
            p.upvotes,
            p.flags,
            p.createdAt
        );
    }

    function projectCount() external view returns (uint256) {
        return _projects.length;
    }
}
