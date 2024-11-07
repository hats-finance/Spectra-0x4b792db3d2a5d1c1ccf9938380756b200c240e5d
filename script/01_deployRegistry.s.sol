// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../src/Registry.sol";
import "../src/proxy/AMTransparentUpgradeableProxy.sol";
import "../src/proxy/AMProxyAdmin.sol";
import "../src/libraries/Roles.sol";
import "openzeppelin-contracts/access/manager/IAccessManager.sol";

// script to deploy the Registry Instance and Proxy
contract RegistryScript is Script {
    bytes4[] private selectors_proxy_admin = new bytes4[](1);
    bytes4[] private fee_methods_selectors = new bytes4[](5);
    bytes4[] private registry_methods_selectors = new bytes4[](7);
    address private testRes;
    uint256 private tokenizationFee;
    uint256 private yieldFee;
    uint256 private ptFlashLoanFee;
    address private feeCollector;
    address private initialAuthority;
    bool private forTest;

    function run() public {
        vm.startBroadcast();
        selectors_proxy_admin[0] = AMProxyAdmin(address(0)).upgradeAndCall.selector;
        fee_methods_selectors[0] = IRegistry(address(0)).setTokenizationFee.selector;
        fee_methods_selectors[1] = IRegistry(address(0)).setYieldFee.selector;
        fee_methods_selectors[2] = IRegistry(address(0)).setPTFlashLoanFee.selector;
        fee_methods_selectors[3] = IRegistry(address(0)).setFeeCollector.selector;
        fee_methods_selectors[4] = IRegistry(address(0)).reduceFee.selector;

        registry_methods_selectors[0] = IRegistry(address(0)).setFactory.selector;
        registry_methods_selectors[1] = IRegistry(address(0)).setPTBeacon.selector;
        registry_methods_selectors[2] = IRegistry(address(0)).setYTBeacon.selector;
        registry_methods_selectors[3] = IRegistry(address(0)).removePT.selector;
        registry_methods_selectors[4] = IRegistry(address(0)).addPT.selector;
        registry_methods_selectors[5] = IRegistry(address(0)).setRouter.selector;
        registry_methods_selectors[6] = IRegistry(address(0)).setRouterUtil.selector;
        if (forTest) {
            Registry registryInstance = new Registry();
            console.log("Registry instance deployed at", address(registryInstance));
            address registryProxy = address(
                new AMTransparentUpgradeableProxy(
                    address(registryInstance),
                    initialAuthority,
                    abi.encodeWithSelector(
                        Registry(address(0)).initialize.selector,
                        initialAuthority
                    )
                )
            );
            console.log("Registry proxy deployed at", registryProxy);
            IRegistry(registryProxy).setTokenizationFee(tokenizationFee);
            IRegistry(registryProxy).setYieldFee(yieldFee);
            IRegistry(registryProxy).setPTFlashLoanFee(ptFlashLoanFee);
            IRegistry(registryProxy).setFeeCollector(feeCollector);

            IAccessManager(initialAuthority).setTargetFunctionRole(
                registryProxy,
                fee_methods_selectors,
                Roles.FEE_SETTER_ROLE
            );

            IAccessManager(initialAuthority).setTargetFunctionRole(
                registryProxy,
                registry_methods_selectors,
                Roles.REGISTRY_ROLE
            );

            bytes32 adminSlot = vm.load(address(registryProxy), ERC1967Utils.ADMIN_SLOT);
            address proxyAdmin = address(uint160(uint256(adminSlot)));
            IAccessManager(initialAuthority).setTargetFunctionRole(
                proxyAdmin,
                selectors_proxy_admin,
                Roles.UPGRADE_ROLE
            );
            console.log("Function setTargetFunctionRole Role set for ProxyAdmin");
            testRes = registryProxy;
        } else {
            string memory deploymentNetwork = vm.envString("DEPLOYMENT_NETWORK");
            if (bytes(deploymentNetwork).length == 0) {
                revert("DEPLOYMENT_NETWORK is not set in .env file");
            }

            string memory envVar = string.concat("ACCESS_MANAGER_ADDRESS_", deploymentNetwork);
            if (bytes(vm.envString(envVar)).length == 0) {
                revert(string.concat(envVar, " is not set in .env file"));
            }
            initialAuthority = vm.envAddress(envVar);

            envVar = string.concat("TOKENIZATION_FEE_", deploymentNetwork);
            if (bytes(vm.envString(envVar)).length == 0) {
                revert(string.concat(envVar, " is not set in .env file"));
            }
            tokenizationFee = vm.envUint(envVar);

            envVar = string.concat("YIELD_FEE_", deploymentNetwork);
            if (bytes(vm.envString(envVar)).length == 0) {
                revert(string.concat(envVar, " is not set in .env file"));
            }
            yieldFee = vm.envUint(envVar);

            envVar = string.concat("PT_FLASH_LOAN_FEE_", deploymentNetwork);
            if (bytes(vm.envString(envVar)).length == 0) {
                revert(string.concat(envVar, " is not set in .env file"));
            }
            ptFlashLoanFee = vm.envUint(envVar);

            envVar = string.concat("FEE_COLLECTOR_", deploymentNetwork);
            if (bytes(vm.envString(envVar)).length == 0) {
                revert(string.concat(envVar, " is not set in .env file"));
            }
            feeCollector = vm.envAddress(envVar);

            address registryInstance = address(new Registry());
            console.log("Registry instance deployed at", registryInstance);
            address registryProxy = address(
                new AMTransparentUpgradeableProxy(
                    registryInstance,
                    initialAuthority,
                    abi.encodeWithSelector(
                        Registry(address(0)).initialize.selector,
                        initialAuthority
                    )
                )
            );
            console.log("Registry proxy deployed at", registryProxy);
            IRegistry(registryProxy).setTokenizationFee(tokenizationFee);
            IRegistry(registryProxy).setYieldFee(yieldFee);
            IRegistry(registryProxy).setPTFlashLoanFee(ptFlashLoanFee);
            IRegistry(registryProxy).setFeeCollector(feeCollector);

            IAccessManager(initialAuthority).setTargetFunctionRole(
                registryProxy,
                fee_methods_selectors,
                Roles.FEE_SETTER_ROLE
            );

            IAccessManager(initialAuthority).setTargetFunctionRole(
                registryProxy,
                registry_methods_selectors,
                Roles.REGISTRY_ROLE
            );

            bytes32 adminSlot = vm.load(address(registryProxy), ERC1967Utils.ADMIN_SLOT);
            address proxyAdmin = address(uint160(uint256(adminSlot)));
            console.log("Registry Proxy Admin Address:", address(proxyAdmin));
            IAccessManager(initialAuthority).setTargetFunctionRole(
                proxyAdmin,
                selectors_proxy_admin,
                Roles.UPGRADE_ROLE
            );
            console.log("Function setTargetFunctionRole Role set for ProxyAdmin");
        }
        vm.stopBroadcast();
    }

    function deployForTest(
        uint256 _tokenizationFee,
        uint256 _yieldFee,
        uint256 _ptFlashLoanFee,
        address _feeCollector,
        address _initialAuthority
    ) public returns (address _testRes) {
        forTest = true;
        tokenizationFee = _tokenizationFee;
        yieldFee = _yieldFee;
        ptFlashLoanFee = _ptFlashLoanFee;
        feeCollector = _feeCollector;
        initialAuthority = _initialAuthority;
        run();
        forTest = false;
        _testRes = testRes;
        testRes = address(0);
        tokenizationFee = 0;
        yieldFee = 0;
        ptFlashLoanFee = 0;
        feeCollector = address(0);
        initialAuthority = address(0);
    }
}
