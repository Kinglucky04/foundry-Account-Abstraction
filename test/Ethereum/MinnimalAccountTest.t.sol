// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinnimalAccount} from "../../src/Ethereum/MinnimalAccount.sol";
import {DeployMinnimalAccount} from "../../script/DeployMinnimalAccount.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "../../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinnimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinnimalAccount minnimalAccount;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    uint256 constant AMOUNT = 1e18;
    address public RANDOM_USER = makeAddr("randomUser");

    function setUp() external {
        DeployMinnimalAccount deployMinnimalAccount = new DeployMinnimalAccount();
        (minnimalAccount, helperConfig) = deployMinnimalAccount.deployMinnimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        uint256 startingBalancebalance = usdc.balanceOf(address(minnimalAccount));
        assertEq(startingBalancebalance, 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minnimalAccount), AMOUNT);

        vm.prank(minnimalAccount.owner());
        minnimalAccount.execute(dest, value, functionData);

        uint256 endingBalance = usdc.balanceOf(address(minnimalAccount));
        assertEq(endingBalance, AMOUNT);
    }

    function testNonOwnerCanNotExecuteCommand() public {
        uint256 startingBalance = usdc.balanceOf(address(minnimalAccount));

        assertEq(startingBalance, 0);

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minnimalAccount), AMOUNT);

        vm.prank(RANDOM_USER);
        vm.expectRevert(MinnimalAccount.MinnimalAccount__NotFromEntryPointOrOwner.selector);
        minnimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        uint256 userStartingBalance = usdc.balanceOf(address(minnimalAccount));
        assertEq(userStartingBalance, 0);

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minnimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinnimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minnimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        assertEq(actualSigner, minnimalAccount.owner());
    }

    function testValidationOfUserOp() public {
        uint256 userStartingBalance = usdc.balanceOf(address(minnimalAccount));
        assertEq(userStartingBalance, 0);

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minnimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinnimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minnimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minnimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommand() public {
        uint256 userStartingBalance = usdc.balanceOf(address(minnimalAccount));
        assertEq(userStartingBalance, 0);

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minnimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinnimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minnimalAccount)
        );
        //bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        vm.deal(address(minnimalAccount), 1e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.prank(RANDOM_USER);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(RANDOM_USER));

        assertEq(usdc.balanceOf(address(minnimalAccount)), AMOUNT);
    }
}
