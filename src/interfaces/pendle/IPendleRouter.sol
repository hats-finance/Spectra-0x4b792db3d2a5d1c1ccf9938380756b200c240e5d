// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IPendleRouter {
    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        // ETH_WETH not used in Aggregator
        ETH_WETH
    }

    enum OrderType {
        SY_FOR_PT,
        PT_FOR_SY,
        SY_FOR_YT,
        YT_FOR_SY
    }

    struct Order {
        uint256 salt;
        uint256 expiry;
        uint256 nonce;
        OrderType orderType;
        address token;
        address YT;
        address maker;
        address receiver;
        uint256 makingAmount;
        uint256 lnImpliedRate;
        uint256 failSafeRate;
        bytes permit;
    }

    struct FillOrderParams {
        Order order;
        bytes signature;
        uint256 makingAmount;
    }

    struct TokenOutput {
        // TOKEN DATA
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        // AGGREGATOR DATA
        address pendleSwap;
        SwapData swapData;
    }

    struct LimitOrderData {
        address limitRouter;
        uint256 epsSkipMarket; // only used for swap operations, will be ignored otherwise
        FillOrderParams[] normalFills;
        FillOrderParams[] flashFills;
        bytes optData;
    }

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);
}
