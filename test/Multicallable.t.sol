// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Multicallable} from "../src/Multicallable.sol";
import {SomeContract} from "./mocks/SomeContract.sol";

contract MulticallableTest is Multicallable, Test {
    SomeContract somecontract;

    address public target;

    function setUp() public {
        somecontract = new SomeContract();
        target = address(somecontract);
    }

    function multicallOriginal(address _target, bytes[] calldata data) public returns (bytes[] memory) {
        bytes[] memory results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = _target.call(data[i]);
            require(success);
            results[i] = result;
        }
        return results;
    }

    function testMulticallableRevertWithMessage(string memory revertMessage) public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(SomeContract.revertsWithString.selector, revertMessage);
        vm.expectRevert(bytes(revertMessage));
        this.multicall(target, data);
    }

    function testMulticallableRevertWithMessage() public {
        testMulticallableRevertWithMessage("Milady");
    }

    function testMulticallableRevertWithCustomError() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(SomeContract.revertsWithCustomError.selector);
        vm.expectRevert(SomeContract.CustomError.selector);
        this.multicall(target, data);
    }

    function testMulticallableRevertWithNothing() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(SomeContract.revertsWithNothing.selector);
        vm.expectRevert();
        this.multicall(target, data);
    }

    function testMulticallableReturnDataIsProperlyEncoded(uint256 a0, uint256 b0, uint256 a1, uint256 b1) public {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SomeContract.returnsTuple.selector, a0, b0);
        data[1] = abi.encodeWithSelector(SomeContract.returnsTuple.selector, a1, b1);
        bytes[] memory returnedData = this.multicall(target, data);
        SomeContract.Tuple memory t0 = abi.decode(returnedData[0], (SomeContract.Tuple));
        SomeContract.Tuple memory t1 = abi.decode(returnedData[1], (SomeContract.Tuple));
        assertEq(t0.a, a0);
        assertEq(t0.b, b0);
        assertEq(t1.a, a1);
        assertEq(t1.b, b1);
    }

    function testMulticallableReturnDataIsProperlyEncoded(string memory sIn0, string memory sIn1, uint256 n) public {
        n = n % 2;
        bytes[] memory dataIn = new bytes[](n);
        if (n > 0) {
            dataIn[0] = abi.encodeWithSelector(SomeContract.returnsString.selector, sIn0);
        }
        if (n > 1) {
            dataIn[1] = abi.encodeWithSelector(SomeContract.returnsString.selector, sIn1);
        }
        bytes[] memory dataOut = this.multicall(target, dataIn);
        if (n > 0) {
            assertEq(abi.decode(dataOut[0], (string)), sIn0);
        }
        if (n > 1) {
            assertEq(abi.decode(dataOut[1], (string)), sIn1);
        }
    }

    function testMulticallableReturnDataIsProperlyEncoded() public {
        testMulticallableReturnDataIsProperlyEncoded(0, 1, 2, 3);
    }

    function testMulticallableBenchmark() public {
        unchecked {
            bytes[] memory data = new bytes[](10);
            for (uint256 i; i != data.length; ++i) {
                data[i] = abi.encodeWithSelector(SomeContract.returnsTuple.selector, i, i + 1);
            }
            bytes[] memory returnedData = this.multicall(target, data);
            assertEq(returnedData.length, data.length);
        }
    }

    function testMulticallableOriginalBenchmark() public {
        unchecked {
            bytes[] memory data = new bytes[](10);
            for (uint256 i; i != data.length; ++i) {
                data[i] = abi.encodeWithSelector(SomeContract.returnsTuple.selector, i, i + 1);
            }
            bytes[] memory returnedData = this.multicallOriginal(target, data);
            assertEq(returnedData.length, data.length);
        }
    }

    function testMulticallableWithNoData() public {
        bytes[] memory data = new bytes[](0);
        assertEq(this.multicall(target, data).length, 0);
    }

    function testMulticallablePreservesMsgValue() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(SomeContract.pay.selector);
        this.multicall{value: 3}(target, data);
        assertEq(somecontract.paid(), 3);
    }

    function testMulticallablePreservesMsgValueUsedTwice() public {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SomeContract.pay.selector);
        data[1] = abi.encodeWithSelector(SomeContract.pay.selector);
        this.multicall{value: 3}(target, data);
        assertEq(somecontract.paid(), 6);
    }

    function testMulticallablePreservesMsgSender() public {
        address caller = address(uint160(0xbeef));
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(SomeContract.returnsSender.selector);
        vm.prank(caller);
        address returnedAddress = abi.decode(this.multicall(target, data)[0], (address));
        assertEq(caller, returnedAddress);
    }
}
