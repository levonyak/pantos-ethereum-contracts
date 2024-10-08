// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {PantosBaseScript} from "./helpers/PantosHubDeployer.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";

/**
 * @title UpdateFeeFactors
 *
 * @notice Update the fee factors at the Pantos Hub.
 *
 * @dev Usage
 * forge script ./script/UpdateFeeFactors.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,address)" <accessControllerAddress> \
 *      <pantosHubProxy>
 */
contract UpdateFeeFactors is PantosBaseScript, SafeAddresses {
    function roleActions(
        address accessControllerAddress,
        address pantosHubProxyAddress
    ) public {
        IPantosHub pantosHubProxy = IPantosHub(pantosHubProxyAddress);
        AccessController accessController = AccessController(
            accessControllerAddress
        );
        vm.startBroadcast(accessController.mediumCriticalOps());

        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));
            if (!blockchain.skip) {
                uint256 blockchainId = uint256(blockchain.blockchainId);
                PantosTypes.UpdatableUint256
                    memory onchainFeeFactor = pantosHubProxy
                        .getValidatorFeeFactor(blockchainId);

                uint256 newFeeFactor = blockchain.feeFactor;
                uint256 currentFeeFactor = onchainFeeFactor.currentValue;
                uint256 pendingFeeFactor = onchainFeeFactor.pendingValue;
                uint256 currentTime = vm.unixTime() / 1000;
                uint256 updateTime = onchainFeeFactor.updateTime;

                bool currentUpToDate = currentFeeFactor == newFeeFactor;
                bool pendingUpToDate = pendingFeeFactor == newFeeFactor;
                bool initiateUpdate = (!currentUpToDate && !pendingUpToDate) ||
                    (!pendingUpToDate && updateTime > 0);
                bool executeUpdate = !currentUpToDate &&
                    pendingUpToDate &&
                    updateTime > 0 &&
                    currentTime >= updateTime;
                assert(!(initiateUpdate && executeUpdate));

                if (initiateUpdate) {
                    pantosHubProxy.initiateValidatorFeeFactorUpdate(
                        blockchainId,
                        newFeeFactor
                    );
                    console.log(
                        "%s: fee factor update initiated",
                        blockchain.name
                    );
                } else if (executeUpdate) {
                    pantosHubProxy.executeValidatorFeeFactorUpdate(
                        blockchainId
                    );
                    console.log(
                        "%s: fee factor update executed",
                        blockchain.name
                    );
                } else {
                    console.log("%s: no fee factor update", blockchain.name);
                }
            }
        }

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
