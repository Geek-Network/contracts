//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IFactory.sol';
import './Pair.sol';

contract Factory is IFactory, Ownable {
    bytes32 public override INIT_CODE_HASH = keccak256(abi.encodePacked(type(Pair).creationCode));

    address public override feeTo;
    // address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    // constructor(address _feeToSetter) {
    //     feeToSetter = _feeToSetter;
    // }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'GEEK: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GEEK: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'GEEK: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override onlyOwner {
        feeTo = _feeTo;
    }

    function setDevFee(address _pair, uint8 _devFee) external override onlyOwner {
        require(_devFee > 0, 'GEEK: FORBIDDEN_FEE');
        Pair(_pair).setDevFee(_devFee);
    }

    function setSwapFee(address _pair, uint32 _swapFee) external override onlyOwner {
        Pair(_pair).setSwapFee(_swapFee);
    }
}
