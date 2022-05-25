//SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import '../libraries/Helper.sol';
import '../libraries/Math.sol';

contract Staking is ReentrancyGuard {
    using Math for uint256;

    // The STAKED TOKEN
    address public immutable STAKED_TOKEN;
    // The REWARD TOKEN
    address public immutable REWARD_TOKEN;
    // The block when stake starts
    uint256 public immutable START_TIME;

    uint256 public immutable PERIOD; // unit in day
    uint256 public immutable TOTAL; // total amount staking
    uint256 public immutable QUOTA; // max amount staking
    uint256 public immutable LIMIT; // limit each user stake

    // epoch era

    /**
     * @notice
      rewardPerHour is 1000 because it is used to represent 0.001, since we only use integer numbers
      This will give users 0.1% reward for each staked token / H
     */
    uint256 public immutable REWARD_PER_PERIOD = 1000;

    bool public immutable LOCKED; // if true, you can't withdraw your money before the deadline

    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    /**
     * @notice
     * A stake struct is used to represent the way we store stakes,
     * A Stake will contain the users address, the amount staked and a timestamp,
     * Since which is when the stake was made
     */
    struct Stake {
        uint256 amount;
        uint256 since;
        // This claimable field is new and used to tell how big of a reward is currently available
        uint256 claimable;
    }

    // user addr -> pool id -> UserSaving[]
    // mapping(address => mapping(uint256 => Stake[])) public stakes;

    mapping(address => Stake[]) public stakes;

    /**
     * @notice
     * calculateStakeReward is used to calculate how much a user should be rewarded for their stakes
     * and the duration the stake has been active
     */
    function calculateStakeReward(Stake memory _stake) internal view returns (uint256) {
        // First calculate how long the stake has been active
        // Use current seconds since epoch - the seconds since epoch the stake was made
        // The output will be duration in SECONDS ,
        // We will reward the user 0.1% per Hour So thats 0.1% per 3600 seconds
        // the alghoritm is  seconds = block.timestamp - stake seconds (block.timestap - _stake.since)
        // hours = Seconds / 3600 (seconds /3600) 3600 is an variable in Solidity names hours
        // we then multiply each token by the hours staked , then divide by the rewardPerHour rate
        return (((block.timestamp - _stake.since) / PERIOD) * _stake.amount) / REWARD_PER_PERIOD;
    }

    function getTotalStaked(Stake[] memory _stakes) internal view returns (uint256 sum) {
        for (uint256 i = 0; i < _stakes.length; i++) {
            sum = sum.add(_stakes[i].amount);
        }
    }

    // View function to see current periods.
    function getPeriodsSinceStart(uint256 _since) public view returns (uint256 periods) {
        uint256 _timestamp = block.timestamp;
        uint256 _start = START_TIME;
        uint256 _period = PERIOD;

        if (_timestamp <= _start) return 0;
        uint256 blocksSinceStart = _timestamp.sub(_start);
        periods = (blocksSinceStart / _period).add(1);
        if (blocksSinceStart % _period == 0) {
            periods = periods - 1;
        }
    }

    /**
     * @dev Stakes tokens
     * @param _amount Amount to stake
     **/
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, 'INVALID_ZERO_AMOUNT');

        Stake[] storage _stakes = stakes[msg.sender];

        uint256 sum = getTotalStaked(_stakes);

        require(TOTAL <= QUOTA && sum <= LIMIT, 'NO MORE SAVING AVAIABLE');

        Helper.safeTransferFrom(STAKED_TOKEN, msg.sender, address(this), _amount);

        // block.timestamp = timestamp of the current block in seconds since the epoch
        uint256 _timestamp = block.timestamp;

        _stakes.push(Stake({amount: _amount, since: _timestamp, claimable: 0}));

        emit Staked(msg.sender, _amount, _timestamp);
    }

    function unstake(uint256 amount) external nonReentrant {}

    function stakeOf(address _holder) public view returns (Stake[] memory) {
        Stake[] memory _stakes = stakes[_holder];

        for (uint256 i = 0; i < _stakes.length; i++) {
            _stakes[i].claimable = calculateStakeReward(_stakes[i]);
        }

        return _stakes;
    }

    function claim() external nonReentrant {
        uint256 claimable = 0;
        Stake[] storage _stakes = stakes[msg.sender];
        for (uint256 i = 0; i < _stakes.length; i++) {
            uint256 reward = calculateStakeReward(_stakes[i]);
            claimable = claimable.add(reward);
        }
        // if (claimable > 0) {

        //     Helper.safeTransfer()

        // }
    }

    /**
     * @dev Redeems staked tokens
     * @param amount Amount to redeem
     **/
    function redeem(uint256 amount) external nonReentrant {
        require(amount > 0, 'INVALID_ZERO_AMOUNT');
        require(block.number > START_BLOCK, 'STAKE_NOT_STARTED');

        StakerInfo storage stakerInfo = _stakerInfos[msg.sender];
        require(amount <= totalStakedAmount, 'INSUFFICIENT_TOTAL_STAKED_AMOUNT');
        require(amount <= stakerInfo.stakedAmount, 'INSUFFICIENT_STAKED_AMOUNT');

        stakerInfo.lastUpdatedBlock = block.number < END_BLOCK ? block.number : END_BLOCK;

        uint256 removedInterest = amount.mul(END_BLOCK.sub(stakerInfo.lastUpdatedBlock));

        totalInterest = totalInterest.sub(removedInterest);
        totalStakedAmount = totalStakedAmount.sub(amount);

        stakerInfo.stakedAmount = stakerInfo.stakedAmount.sub(amount);
        stakerInfo.accInterest = stakerInfo.accInterest.sub(removedInterest);

        Helper.safeTransfer(STAKED_TOKEN, msg.sender, amount);
        emit Redeem(msg.sender, amount, removedInterest);
    }
}
