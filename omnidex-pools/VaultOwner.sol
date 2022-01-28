pragma solidity 0.6.12;

import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/access/Ownable.sol';
import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import './CharmVault.sol';

contract VaultOwner is Ownable {
    using SafeERC20 for IERC20;

    CharmVault public immutable charmVault;

    /**
     * @notice Constructor
     * @param _charmVaultAddress: CharmVault contract address
     */
    constructor(address _charmVaultAddress) public {
        charmVault = CharmVault(_charmVaultAddress);
    }

    /**
     * @notice Sets admin address to this address
     * @dev Only callable by the contract owner.
     * It makes the admin == owner.
     */
    function setAdmin() external onlyOwner {
        charmVault.setAdmin(address(this));
    }

    /**
     * @notice Sets treasury address
     * @dev Only callable by the contract owner.
     */
    function setTreasury(address _treasury) external onlyOwner {
        charmVault.setTreasury(_treasury);
    }

    /**
     * @notice Sets performance fee
     * @dev Only callable by the contract owner.
     */
    function setPerformanceFee(uint256 _performanceFee) external onlyOwner {
        charmVault.setPerformanceFee(_performanceFee);
    }

    /**
     * @notice Sets call fee
     * @dev Only callable by the contract owner.
     */
    function setCallFee(uint256 _callFee) external onlyOwner {
        charmVault.setCallFee(_callFee);
    }

    /**
     * @notice Sets withdraw fee
     * @dev Only callable by the contract owner.
     */
    function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
        charmVault.setWithdrawFee(_withdrawFee);
    }

    /**
     * @notice Sets withdraw fee period
     * @dev Only callable by the contract owner.
     */
    function setWithdrawFeePeriod(uint256 _withdrawFeePeriod) external onlyOwner {
        charmVault.setWithdrawFeePeriod(_withdrawFeePeriod);
    }

    /**
     * @notice Withdraw unexpected tokens sent to the Charm Vault
     */
    function inCaseTokensGetStuck(address _token) external onlyOwner {
        charmVault.inCaseTokensGetStuck(_token);
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Triggers stopped state
     * @dev Only possible when contract not paused.
     */
    function pause() external onlyOwner {
        charmVault.pause();
    }

    /**
     * @notice Returns to normal state
     * @dev Only possible when contract is paused.
     */
    function unpause() external onlyOwner {
        charmVault.unpause();
    }
}