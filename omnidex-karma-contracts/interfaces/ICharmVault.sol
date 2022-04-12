// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ICharmVault {
    
    event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);
    event Harvest(address indexed sender, uint256 performanceFee, uint256 callFee);
    event Pause();
    event Unpause();
    
    function deposit(uint256 _amount) external;
    function withdrawAll() external;
    function harvest(address _caller) external;
    
    function calculateHarvestCharmRewards() external view returns (uint256);
    function calculateTotalPendingCharmRewards() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function withdraw(uint256 _shares) external;
    function available() external view returns (uint256);
    function balanceOf() external view returns (uint256);
}