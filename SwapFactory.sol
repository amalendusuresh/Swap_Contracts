// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SwapPair.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Factory
 * @dev This contract manages the creation of new trading pairs and maintains a registry of all pairs.
 */
contract Factory is Initializable, OwnableUpgradeable {
    /// @notice Mapping from token pair to pair contract address
    mapping(address => mapping(address => address)) public getPair;
    /// @notice Array of all pair addresses
    address[] public allPairs;

    /// @notice Event emitted when a new pair is created
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /**
     * @dev Initializes the contract.
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    /**
     * @notice Creates a new pair for the given tokens.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @return pair Address of the newly created pair contract.
     */
    function createPair(address tokenA, address tokenB) external onlyOwner returns (address pair) {
        require(tokenA != tokenB, "Factory: IDENTICAL_ADDRESSES");
        require(getPair[tokenA][tokenB] == address(0), "Factory: PAIR_EXISTS");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // Allow reverse lookup
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}