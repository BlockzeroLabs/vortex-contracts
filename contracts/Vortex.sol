// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Portal.sol";

contract Vortex {
    address[] public portals;

    event PortalCreated(address portal);

    function createPortal(
        uint256 _endBlock,
        address[] memory _rewardsToken,
        uint256[] memory _minimumRewardRate,
        address _stakingToken,
        uint256 _stakeLimit,
        uint256 _contractStakeLimit,
        uint256 _distributionLimit
    ) external {
        Portal portal = new Portal(
            _endBlock,
            _rewardsToken,
            _minimumRewardRate,
            _stakingToken,
            _stakeLimit,
            _contractStakeLimit,
            _distributionLimit,
            msg.sender
        );

        portals.push(address(portal));
        emit PortalCreated(address(portal));
    }

    function allPortalsLength() external view returns (uint256) {
        return portals.length;
    }
}
