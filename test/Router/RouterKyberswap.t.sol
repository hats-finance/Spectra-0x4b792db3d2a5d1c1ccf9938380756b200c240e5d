// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

// import {RouterBaseTest} from "./RouterBaseTest.t.sol";
import "script/00_deployAccessManager.s.sol";
import "script/01_deployRegistry.s.sol";
import "script/09_deployRouter.s.sol";
import {Math} from "openzeppelin-math/Math.sol";
import {Commands} from "src/router/Commands.sol";
import {Constants} from "src/router/Constants.sol";
import {Roles} from "src/libraries/Roles.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract ContractRouterKyberswapTest is Test {
    using Math for uint256;

    uint256 public fork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address public other = 0x0000000000000000000000000000000000011111;

    address accessManager;
    address router;

    address scriptAdmin;
    address testUser;

    address WETH;
    address stETH;
    address kyberRouter;

    function setUp() public {
        fork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(fork);

        scriptAdmin = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        testUser = address(this);

        // mainnet addresses
        WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        kyberRouter = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;

        AccessManagerDeploymentScript accessManagerScript = new AccessManagerDeploymentScript();
        accessManager = accessManagerScript.deployForTest(scriptAdmin);

        // deploy registry
        RegistryScript registryScript = new RegistryScript();
        address registry = registryScript.deployForTest(0, 0, 0, address(0xFEE), accessManager);
        vm.prank(scriptAdmin);
        IAccessManager(accessManager).grantRole(Roles.REGISTRY_ROLE, scriptAdmin, 0);

        // deploy router
        RouterScript routerScript = new RouterScript();
        (router, , ) = routerScript.deployForTest(registry, kyberRouter, address(0), accessManager);

        // deal ETH
        vm.deal(testUser, 1000e18);

        // deal WETH
        deal(WETH, testUser, 1000e18);
        IERC20(WETH).approve(router, 1000e18);
    }

    // -----------------------
    // --- EXECUTION TESTS ---
    // -----------------------

    function testSwapWETH_stETH() public {
        uint256 amountIn = 2e17;

        // fetch targetData + expectedAmountOut off-chain and paste them here
        bytes memory targetData = hex"";
        uint256 expectedAmountOut = 0;

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.TRANSFER_FROM)),
            bytes1(uint8(Commands.KYBER_SWAP))
        );
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(WETH, amountIn);
        inputs[1] = abi.encode(WETH, amountIn, stETH, expectedAmountOut, targetData);

        uint256 previewRate = IRouter(router).previewRate(commands, inputs);
        uint256 expectedStETH = amountIn.mulDiv(previewRate, 1e27, Math.Rounding.Ceil);

        uint256 wethBalBefore = IERC20(WETH).balanceOf(testUser);
        uint256 stETHBalBefore = IERC20(stETH).balanceOf(router);

        IRouter(router).execute(commands, inputs);

        uint256 wethBalAfter = IERC20(WETH).balanceOf(testUser);
        uint256 stETHBalAfter = IERC20(stETH).balanceOf(router);

        assertEq(wethBalBefore - wethBalAfter, amountIn);
        assertApproxEqRel(expectedStETH, expectedAmountOut, 1e16);
        assertApproxEqRel(stETHBalAfter - stETHBalBefore, expectedAmountOut, 1e16);
    }

    function testSwapETH_stETH() public {
        uint256 amountIn = 2e17;

        // fetch targetData + expectedAmountOut off-chain and paste them here
        bytes memory targetData = hex"";
        uint256 expectedAmountOut = 0;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.KYBER_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, amountIn, stETH, expectedAmountOut, targetData);

        uint256 previewRate = IRouter(router).previewRate(commands, inputs);
        uint256 expectedStETH = amountIn.mulDiv(previewRate, 1e27, Math.Rounding.Ceil);

        uint256 ethBalBefore = testUser.balance;
        uint256 stETHBalBefore = IERC20(stETH).balanceOf(router);

        IRouter(router).execute{value: amountIn}(commands, inputs);

        uint256 ethBalAfter = testUser.balance;
        uint256 stETHBalAfter = IERC20(stETH).balanceOf(router);

        assertEq(ethBalBefore - ethBalAfter, amountIn);
        assertApproxEqRel(expectedStETH, expectedAmountOut, 1e16);
        assertApproxEqRel(stETHBalAfter - stETHBalBefore, expectedAmountOut, 1e16);
    }
}
