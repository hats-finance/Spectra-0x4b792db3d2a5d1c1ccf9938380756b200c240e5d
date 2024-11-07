// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "openzeppelin-math/Math.sol";

import "script/00_deployAccessManager.s.sol";
import "script/01_deployRegistry.s.sol";
import "script/09_deployRouter.s.sol";

import {Commands} from "src/router/Commands.sol";
import {Constants} from "src/router/Constants.sol";
import {IPendleRouter} from "src/interfaces/pendle/IPendleRouter.sol";

contract ContractRouterPendleTest is Test {
    using Math for uint256;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address accessManager;
    address router;
    address scriptAdmin;
    address testUser;

    // mainnet addresses
    address wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address wstETHMarket = 0x34280882267ffa6383B363E278B027Be083bBe3b;
    address lpHolder = 0xF29c734C6150d439Ce72BefE7f965fDb6677737f;
    address lpUser = address(this);
    uint256 amountIn = 1000000000000000000;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL, 21029091);

        scriptAdmin = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        testUser = address(this);

        AccessManagerDeploymentScript accessManagerScript = new AccessManagerDeploymentScript();
        accessManager = accessManagerScript.deployForTest(scriptAdmin);

        // deploy registry
        RegistryScript registryScript = new RegistryScript();
        address registry = registryScript.deployForTest(0, 0, 0, address(0xFEE), accessManager);
        vm.prank(scriptAdmin);
        IAccessManager(accessManager).grantRole(Roles.REGISTRY_ROLE, scriptAdmin, 0);

        // deploy router
        RouterScript routerScript = new RouterScript();
        (router, , ) = routerScript.deployForTest(
            registry,
            address(0),
            address(0x888888888889758F76e7103c6CbF23ABbF58F946),
            accessManager
        );

        // deal ETH
        vm.deal(lpUser, 1000e18);
    }

    error CallFailed();

    function testRemovePendleLiquidity() public {
        // instead of minting tokens, we transfer them from the holder
        vm.prank(lpHolder);
        IERC20(wstETHMarket).transfer(address(this), amountIn);

        // withdraw liquidity
        IERC20(wstETHMarket).approve(address(router), amountIn);
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.TRANSFER_FROM)),
            bytes1(uint8(Commands.PENDLE_REMOVE_LIQUIDITY_SINGLE_TOKEN))
        );
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(wstETHMarket, amountIn);

        address receiver = lpUser;
        address market = wstETHMarket;
        uint256 netLpToRemove = amountIn;

        // result from https://api-v2.pendle.finance/core/v1/sdk/1/markets/0x34280882267ffa6383b363e278b027be083bbe3b/remove-liquidity?receiver=0xF29c734C6150d439Ce72BefE7f965fDb6677737f&tokenOut=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0&amountIn=1000000000000000000&slippage=0.01
        inputs[1] = abi.encode(
            receiver,
            market,
            netLpToRemove,
            IPendleRouter.TokenOutput({
                tokenOut: wstETH,
                minTokenOut: 1704750308580397766,
                tokenRedeemSy: wstETH,
                pendleSwap: address(0),
                swapData: IPendleRouter.SwapData({
                    swapType: IPendleRouter.SwapType.NONE,
                    extRouter: address(0),
                    extCalldata: bytes(""),
                    needScale: false
                })
            }),
            IPendleRouter.LimitOrderData({
                limitRouter: address(0),
                epsSkipMarket: 0,
                normalFills: new IPendleRouter.FillOrderParams[](0),
                flashFills: new IPendleRouter.FillOrderParams[](0),
                optData: bytes("")
            })
        );

        uint256 oldBalance = IERC20(wstETH).balanceOf(lpUser);

        // NOTE: this command requires the PUSH0 opcode to be activated in the VM (else, throwing NotActivated).
        // Make sure to run this test with the correct EVM version (at least Shanghai).
        // e.g. `--evm-version shanghai`
        // https://github.com/foundry-rs/foundry/issues/4988#issuecomment-1556331314
        IRouter(router).execute(commands, inputs);
        uint256 newBalance = IERC20(wstETH).balanceOf(lpUser);

        assertGe(newBalance - oldBalance, 1704750308580397766, "wrong amount of wstETH received");
    }
}
