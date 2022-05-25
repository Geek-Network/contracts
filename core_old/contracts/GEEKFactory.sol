//SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import './interfaces/IGEEKFactory.sol';
import './GEEKPair.sol';

contract GEEKFactory is IGEEKFactory {
    address public feeTo;
    address public feeToSetter;
    bytes32 public INIT_CODE_HASH = keccak256(abi.encodePacked(type(GEEKPair).creationCode));

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'GEEK: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GEEK: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'GEEK: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(GEEKPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IGEEKPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'GEEK: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'GEEK: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setDevFee(address _pair, uint8 _devFee) external {
        require(msg.sender == feeToSetter, 'GEEK: FORBIDDEN');
        require(_devFee > 0, 'GEEK: FORBIDDEN_FEE');
        GEEKPair(_pair).setDevFee(_devFee);
    }
    
    function setSwapFee(address _pair, uint32 _swapFee) external {
        require(msg.sender == feeToSetter, 'GEEK: FORBIDDEN');
        GEEKPair(_pair).setSwapFee(_swapFee);
    }
}
