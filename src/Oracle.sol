// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Oracle {
    // Step 1.2 - State variables (in the required order)
    address public owner;
    address[] public nodes;
    mapping(address => bool) public isNode;

    // Step 2.1 - Round struct
    struct Round {
        uint256 id;
        uint256 totalSubmissionCount;
        uint256 lastUpdatedAt;
    }

    // Step 2.2 - Round and submission tracking (after isNode, before currentPrices)
    mapping(string => Round) public rounds;
    mapping(string => mapping(uint256 => mapping(address => uint256))) public nodePrices;
    mapping(string => mapping(uint256 => mapping(address => bool))) public hasSubmitted;

    // Step 1.2 - currentPrices after the above
    mapping(string => uint256) public currentPrices;

    // Step 2.3 - Event
    event PriceUpdated(string indexed coin, uint256 price, uint256 roundId);

    // Step 1.3 - Constructor
    constructor() {
        owner = msg.sender;
    }

    // Step 1.4 - Quorum calculation
    function getQuorum() public view returns (uint256) {
        uint256 count = nodes.length;
        if (count < 3) {
            return 3;
        }
        // ceil(2/3 * count) = (count * 2 + 2) / 3
        return (count * 2 + 2) / 3;
    }

    // Step 1.5 - Add node
    function addNode() public {
        require(!isNode[msg.sender], "Node already exists");
        isNode[msg.sender] = true;
        nodes.push(msg.sender);
    }

    // Step 1.6 - Remove node (swap-and-pop)
    function removeNode() public {
        require(isNode[msg.sender], "Node does not exist");
        isNode[msg.sender] = false;

        uint256 length = nodes.length;
        for (uint256 i = 0; i < length; i++) {
            if (nodes[i] == msg.sender) {
                uint256 lastIndex = length - 1;
                if (i != lastIndex) {
                    nodes[i] = nodes[lastIndex];
                }
                nodes.pop();
                break;
            }
        }
    }

    // Step 3.1 - Submit price
    function submitPrice(string memory coin, uint256 price) public {
        require(isNode[msg.sender], "Not a node");

        Round storage r = rounds[coin];
        uint256 roundId = r.id;

        require(!hasSubmitted[coin][roundId][msg.sender], "Already submitted for this round");

        nodePrices[coin][roundId][msg.sender] = price;
        hasSubmitted[coin][roundId][msg.sender] = true;
        r.totalSubmissionCount += 1;

        if (r.totalSubmissionCount >= getQuorum()) {
            _finalizePrice(coin, roundId);
        }
    }

    // Step 3.2 - Finalize price
    function _finalizePrice(string memory coin, uint256 roundId) internal {
        uint256 total;
        uint256 count;

        uint256 n = nodes.length;
        for (uint256 i = 0; i < n; i++) {
            address node = nodes[i];
            if (hasSubmitted[coin][roundId][node]) {
                total += nodePrices[coin][roundId][node];
                count += 1;
            }
        }

        if (count > 0) {
            uint256 avg = total / count;
            currentPrices[coin] = avg;
            emit PriceUpdated(coin, avg, roundId);
        }

        Round storage r = rounds[coin];
        r.id += 1;
        r.totalSubmissionCount = 0;
        r.lastUpdatedAt = block.timestamp;
    }
}
