// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinnimalAccount is IAccount, Ownable {
    //////////////////////
    /// Errors     ///
    ////////////////////
    error MinnimalAccount__NotFromEntryPoint();
    error MinnimalAccount__NotFromEntryPointOrOwner();
    error MinnimalAccount__CallFailed(bytes result);

    //////////////////////////
    /// State Variables   ///
    ////////////////////////

    IEntryPoint private immutable i_entryPoint;

    //////////////////////
    /// Modifiers     ///
    ////////////////////

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinnimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointorOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinnimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    //////////////////////
    ///  Functions    ///
    /////////////////////

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    //////////////////////////////
    /// External Functions    ///
    /////////////////////////////

    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointorOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MinnimalAccount__CallFailed(result);
        }
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        // validate nounce: this will be carried out by the entrypoint.sol hence there's no point in validating
        _payPrefund(missingAccountFunds);
    }

    //////////////////////////////
    /// Internal Functions    ///
    /////////////////////////////

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 toEthSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(toEthSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        } else {
            return SIG_VALIDATION_SUCCESS;
        }
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    //////////////////
    /// Getters    ///
    //////////////////

    function getEntryPoint() public view returns (address) {
        return address(i_entryPoint);
    }
}
