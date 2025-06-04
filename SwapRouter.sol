// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SwapFactory.sol";
import "./SwapPair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Router
 * @dev This contract facilitates adding and removing liquidity, as well as token swaps.
 */
contract Router is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Address of the factory contract
    address public factory;

    /**
     * @dev Initializes the router with the factory address.
     * @param _factory Address of the factory contract.
     */
    function initialize(address _factory) public initializer {
        __Ownable_init(msg.sender);
        factory = _factory;
    }

    /**
     * @notice Adds liquidity to a pair.
     * @param tokenA Address of token A.
     * @param tokenB Address of token B.
     * @param amountADesired Desired amount of token A.
     * @param amountBDesired Desired amount of token B.
     * @param amountAMin Minimum amount of token A.
     * @param amountBMin Minimum amount of token B.
     * @return amountA Actual amount of token A added.
     * @return amountB Actual amount of token B added.
     * @return liquidity Amount of liquidity tokens minted.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Router: PAIR_NOT_EXISTS");

        (uint112 reserveA, uint112 reserveB,) = Pair(pair).getReserves();
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired, "Router: INSUFFICIENT_A_AMOUNT");
                require(amountAOptimal >= amountAMin, "Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }

        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = Pair(pair).addLiquidity(amountA, amountB);
    }

    /**
     * @notice Removes liquidity from a pair.
     * @param tokenA Address of token A.
     * @param tokenB Address of token B.
     * @param liquidity Amount of liquidity tokens to remove.
     * @param amountAMin Minimum amount of token A.
     * @param amountBMin Minimum amount of token B.
     * @return amountA Actual amount of token A removed.
     * @return amountB Actual amount of token B removed.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Router: PAIR_NOT_EXISTS");

        (amountA, amountB) = Pair(pair).removeLiquidity(liquidity);
        require(amountA >= amountAMin, "Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "Router: INSUFFICIENT_B_AMOUNT");

        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);
    }

    /**
     * @notice Swaps an exact amount of input tokens for as many output tokens as possible.
     * @param amountIn Amount of input tokens.
     * @param path Array of token addresses (path of the swap).
     * @param to Address to receive the output tokens.
     * @param amountOutMin Minimum amount of output tokens.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amounts Array of output amounts for each token in the path.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        address[] calldata path,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "Router: INVALID_PATH");
        require(block.timestamp <= deadline, "Router: EXPIRED");

        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Router: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(path[0]).safeTransferFrom(msg.sender, Factory(factory).getPair(path[0], path[1]), amounts[0]);

        for (uint256 i; i < path.length - 1; i++) {
            address input = path[i];
            address output = path[i + 1];
            address pair = Factory(factory).getPair(input, output);
            require(pair != address(0), "Router: PAIR_NOT_EXISTS");

            Pair(pair).swap(amounts[i], address(this));
        }

        IERC20(path[path.length - 1]).safeTransfer(to, amounts[amounts.length - 1]);
    }

    /**
     * @notice Gets the reserves of a pair.
     * @param tokenA Address of token A.
     * @param tokenB Address of token B.
     * @return reserveA Reserve of token A.
     * @return reserveB Reserve of token B.
     */
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
        address pair = Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Router: PAIR_NOT_EXISTS");

        (reserveA, reserveB,) = Pair(pair).getReserves();
    }

    /**
     * @notice Calculates the amounts of output tokens for a given input amount.
     * @param amountIn Amount of input tokens.
     * @param path Array of token addresses (path of the swap).
     * @return amounts Array of output amounts for each token in the path.
     */
    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "Router: INVALID_PATH");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            address input = path[i];
            address output = path[i + 1];
            address pair = Factory(factory).getPair(input, output);
            require(pair != address(0), "Router: PAIR_NOT_EXISTS");

            (uint112 reserveIn, uint112 reserveOut,) = Pair(pair).getReserves();
            amounts[i + 1] = Pair(pair).getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice Calculates the amounts of input tokens for a given output amount.
     * @param amountOut Amount of output tokens.
     * @param path Array of token addresses (path of the swap).
     * @return amounts Array of input amounts for each token in the path.
     */
    function getAmountsIn(uint256 amountOut, address[] memory path) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "Router: INVALID_PATH");

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            address input = path[i - 1];
            address output = path[i];
            address pair = Factory(factory).getPair(input, output);
            require(pair != address(0), "Router: PAIR_NOT_EXISTS");

            (uint112 reserveIn, uint112 reserveOut,) = Pair(pair).getReserves();
            amounts[i - 1] = Pair(pair).getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset.
     * @param amountA Amount of asset A.
     * @param reserveA Reserve of asset A.
     * @param reserveB Reserve of asset B.
     * @return amountB Equivalent amount of asset B.
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        require(amountA > 0, "Router: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "Router: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }
}