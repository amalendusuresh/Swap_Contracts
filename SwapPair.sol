// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title Pair
 * @dev This contract manages the liquidity pool for a specific trading pair, including adding/removing liquidity and swapping tokens.
 */
contract Pair is Initializable, ERC20Upgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Address of the first token in the pair
    address public token0;
    /// @notice Address of the second token in the pair
    address public token1;

    uint112 private reserve0; // Using uint112 to save gas
    uint112 private reserve1; // Using uint112 to save gas
    uint32 private blockTimestampLast; // Last block timestamp

    /// @notice Fee rate in basis points (e.g., 30 for 0.3%)
    uint256 public feeRate;

    /// @notice Event emitted when liquidity is added
    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    /// @notice Event emitted when liquidity is removed
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    /// @notice Event emitted when tokens are swapped
    event TokensSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /**
     * @dev Initializes the contract with the given tokens.
     * @param _token0 Address of the first token.
     * @param _token1 Address of the second token.
     */
    function initialize(address _token0, address _token1) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);
        __ERC20_init("Liquidity Token", "LQT"); // Initialize ERC20 with name and symbol
        token0 = _token0;
        token1 = _token1;
        feeRate = 30; // Default fee rate of 0.3%
    }

    /**
     * @notice Sets the fee rate.
     * @param _feeRate New fee rate in basis points.
     */
    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 10000, "Invalid fee rate");
        feeRate = _feeRate;
    }

    /**
     * @notice Adds liquidity to the pool.
     * @param amount0 Amount of token0 to add.
     * @param amount1 Amount of token1 to add.
     * @return liquidity Amount of liquidity tokens minted.
     */
    function addLiquidity(uint256 amount0, uint256 amount1) external nonReentrant returns (uint256 liquidity) {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        reserve0 = _reserve0 + uint112(amount0);
        reserve1 = _reserve1 + uint112(amount1);

        liquidity = amount0 + amount1; // Simplified liquidity calculation
        _mint(msg.sender, liquidity);

        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity);
    }

    /**
     * @notice Removes liquidity from the pool.
     * @param liquidity Amount of liquidity tokens to burn.
     * @return amount0 Amount of token0 received.
     * @return amount1 Amount of token1 received.
     */
    function removeLiquidity(uint256 liquidity) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(balanceOf(msg.sender) >= liquidity, "Insufficient liquidity");

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        amount0 = (liquidity * _reserve0) / totalSupply();
        amount1 = (liquidity * _reserve1) / totalSupply();

        _burn(msg.sender, liquidity);

        reserve0 = _reserve0 - uint112(amount0);
        reserve1 = _reserve1 - uint112(amount1);

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
    }

    /**
     * @notice Swaps an input amount of one token for as much as possible of the other token.
     * @param amountIn Amount of input tokens to swap.
     * @param to Address to receive the output tokens.
     * @return amountOut Amount of output tokens received.
     */
    function swap(uint256 amountIn, address to) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than zero");
        require(to != address(0), "Invalid recipient address");

        address inputToken = msg.sender == token0 ? token0 : token1;
        address outputToken = inputToken == token0 ? token1 : token0;

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 reserveInput = inputToken == token0 ? _reserve0 : _reserve1;
        uint256 reserveOutput = inputToken == token0 ? _reserve1 : _reserve0;

        amountOut = getAmountOut(amountIn, reserveInput, reserveOutput);

        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(outputToken).safeTransfer(to, amountOut);

        if (inputToken == token0) {
            reserve0 = _reserve0 + uint112(amountIn);
            reserve1 = _reserve1 - uint112(amountOut);
        } else {
            reserve1 = _reserve1 + uint112(amountIn);
            reserve0 = _reserve0 - uint112(amountOut);
        }

        emit TokensSwapped(inputToken, outputToken, amountIn, amountOut);
    }

    /**
     * @notice Returns the output amount for a given input amount and reserves.
     * @param amountIn Amount of input tokens.
     * @param reserveIn Reserve of input tokens.
     * @param reserveOut Reserve of output tokens.
     * @return amountOut Amount of output tokens.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * (10000 - feeRate) / 10000;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @notice Returns the input amount for a given output amount and reserves.
     * @param amountOut Amount of output tokens.
     * @param reserveIn Reserve of input tokens.
     * @param reserveOut Reserve of output tokens.
     * @return amountIn Amount of input tokens.
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountIn) {
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * (10000 - feeRate);
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @notice Returns the reserves of the pair.
     * @return _reserve0 Reserve of token0.
     * @return _reserve1 Reserve of token1.
     * @return _blockTimestampLast Last block timestamp.
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev Override to use ContextUpgradeable's _msgSender.
     * @return The address of the sender.
     */
    function _msgSender() internal view override(ContextUpgradeable) returns (address) {
        return ContextUpgradeable._msgSender();
    }

    /**
     * @dev Override to use ContextUpgradeable's _msgData.
     * @return The calldata of the sender.
     */
    function _msgData() internal view override(ContextUpgradeable) returns (bytes calldata) {
        return ContextUpgradeable._msgData();
    }
}