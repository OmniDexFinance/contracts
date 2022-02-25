pragma solidity 0.6.12;

import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/utils/Pausable.sol';
import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/access/Ownable.sol';
import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/math/SafeMath.sol';
import 'https://github.com/OmniDexFinance/helper/blob/master/%40openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IZenMaster.sol';

contract CharmVaultV2 is Ownable, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 shares; // number of shares for a user
        uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
        uint256 charmAtLastUserAction; // keeps track of charm deposited at the last user action
        uint256 lastUserActionTime; // keeps track of the last user action time
    }

    IERC20 public immutable token; // Charm token
    IERC20 public immutable receiptToken; // Syrup token

    IZenMaster public immutable zenmaster;

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public isAuthorized; // set of addresses that can perform certain functions

    uint256 public totalShares;
    uint256 public lastHarvestedTime;
    address public admin;
    address public treasury;
    address public furnance;

    uint256 public constant MAX_PERFORMANCE_FEE = 2500; // 25%
    uint256 public constant MAX_CALL_FEE = 2500; // 25%
    uint256 public constant MAX_BURN_FEE = 2500; // 25%
    uint256 public constant MAX_WITHDRAW_FEE = 2500; // 25%
    uint256 public constant MAX_WITHDRAW_FEE_PERIOD = 168 hours; // 7 days

    uint256 public performanceFee = 500; // 5%
    uint256 public callFee = 100; // 1%
    uint256 public burnFee = 200; // 2%
    uint256 public withdrawFee = 0; // 10 == 0.1%
    uint256 public withdrawFeePeriod = 0 hours; // 72 hours == 3 days

    event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);
    event Harvest(address indexed sender, uint256 performanceFee, uint256 callFee);
    event Pause();
    event Unpause();

    /**
     * @notice Constructor
     * @param _token: Charm token contract
     * @param _receiptToken: Syrup token contract
     * @param _zenmaster: ZenMaster contract
     * @param _admin: address of the admin
     * @param _treasury: address of the treasury (collects fees)
     * @param _furnance: address of the furnance (burns tokens)
     */
    constructor(
        IERC20 _token,
        IERC20 _receiptToken,
        IZenMaster _zenmaster,
        address _admin,
        address _treasury,
        address _furnance
    ) public {
        token = _token;
        receiptToken = _receiptToken;
        zenmaster = _zenmaster;
        admin = _admin;
        treasury = _treasury;
        furnance = _furnance;

        // Infinite approve
        IERC20(_token).safeApprove(address(_zenmaster), uint256(-1));
    }

    /**
     * @notice Checks if the msg.sender is the admin address
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "admin: wut?");
        _;
    }

    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender], "auth: FORBIDDEN");
        _;
    }

    /**
     * @notice Deposits funds into the Charm Vault
     * @dev Only possible when contract not paused.
     * @param _amount: number of tokens to deposit (in CHARM)
     */
    function deposit(uint256 _amount) external whenNotPaused onlyAuthorized {
        require(_amount > 0, "Nothing to deposit");

        uint256 pool = balanceOf();
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 currentShares = 0;
        if (totalShares != 0) {
            currentShares = (_amount.mul(totalShares)).div(pool);
        } else {
            currentShares = _amount;
        }
        UserInfo storage user = userInfo[msg.sender];

        user.shares = user.shares.add(currentShares);
        user.lastDepositedTime = block.timestamp;

        totalShares = totalShares.add(currentShares);

        user.charmAtLastUserAction = user.shares.mul(balanceOf()).div(totalShares);
        user.lastUserActionTime = block.timestamp;

        _earn();

        emit Deposit(msg.sender, _amount, currentShares, block.timestamp);
    }

    /**
     * @notice Withdraws all funds for a user
     */
    function withdrawAll() external onlyAuthorized {
        withdraw(userInfo[msg.sender].shares);
    }

    /**
     * @notice Reinvests CHARM tokens into ZenMaster
     * @dev Only possible when contract not paused.
     */
    function harvest(address _caller) external onlyAuthorized whenNotPaused {
        IZenMaster(zenmaster).leaveStaking(0);

        uint256 bal = available();
        uint256 currentPerformanceFee = bal.mul(performanceFee).div(10000);
        token.safeTransfer(treasury, currentPerformanceFee);

        uint256 currentCallFee = bal.mul(callFee).div(10000);
        token.safeTransfer(_caller, currentCallFee);
        
        uint256 currentBurnFee = bal.mul(burnFee).div(10000);
        token.safeTransfer(furnance, currentBurnFee);

        _earn();

        lastHarvestedTime = block.timestamp;

        emit Harvest(_caller, currentPerformanceFee, currentCallFee);
    }

    /**
     * @notice Sets admin address
     * @dev Only callable by the contract owner.
     */
    function setAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Cannot be zero address");
        admin = _admin;
    }

    /**
     * @notice Sets treasury address
     * @dev Only callable by the contract owner.
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Cannot be zero address");
        treasury = _treasury;
    }

    /**
     * @notice Sets burn address
     * @dev Only callable by the contract owner.
     */
    function setFurnance(address _furnance) external onlyOwner {
        require(_furnance != address(0), "Cannot be zero address");
        furnance = _furnance;
    }

    /**
     * @notice Sets performance fee
     * @dev Only callable by the contract admin.
     */
    function setPerformanceFee(uint256 _performanceFee) external onlyAdmin {
        require(_performanceFee <= MAX_PERFORMANCE_FEE, "performanceFee cannot be more than MAX_PERFORMANCE_FEE");
        performanceFee = _performanceFee;
    }

    /**
     * @notice Sets call fee
     * @dev Only callable by the contract admin.
     */
    function setCallFee(uint256 _callFee) external onlyAdmin {
        require(_callFee <= MAX_CALL_FEE, "callFee cannot be more than MAX_CALL_FEE");
        callFee = _callFee;
    }

    /**
     * @notice Sets burn fee
     * @dev Only callable by the contract admin.
     */
    function setBurnFee(uint256 _burnFee) external onlyAdmin {
        require(_burnFee <= MAX_BURN_FEE, "burnFee cannot be more than MAX_BURN_FEE");
        burnFee = _burnFee;
    }

    /**
     * @notice Sets withdraw fee
     * @dev Only callable by the contract admin.
     */
    function setWithdrawFee(uint256 _withdrawFee) external onlyAdmin {
        require(_withdrawFee <= MAX_WITHDRAW_FEE, "withdrawFee cannot be more than MAX_WITHDRAW_FEE");
        withdrawFee = _withdrawFee;
    }

    /**
     * @notice Sets withdraw fee period
     * @dev Only callable by the contract admin.
     */
    function setWithdrawFeePeriod(uint256 _withdrawFeePeriod) external onlyAdmin {
        require(
            _withdrawFeePeriod <= MAX_WITHDRAW_FEE_PERIOD,
            "withdrawFeePeriod cannot be more than MAX_WITHDRAW_FEE_PERIOD"
        );
        withdrawFeePeriod = _withdrawFeePeriod;
    }

    /**
     * @notice Withdraws from ZenMaster to Vault without caring about rewards.
     * @dev EMERGENCY ONLY. Only callable by the contract admin.
     */
    function emergencyWithdraw() external onlyAdmin {
        IZenMaster(zenmaster).emergencyWithdraw(0);
        
        if(totalShares == 0) {
            token.safeTransfer(treasury, available());
        }
    }

    /**
     * @notice Withdraw unexpected tokens sent to the Charm Vault
     */
    function inCaseTokensGetStuck(address _token) external onlyAdmin {
        require(_token != address(token), "Token cannot be same as deposit token");
        require(_token != address(receiptToken), "Token cannot be same as receipt token");

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Triggers stopped state
     * @dev Only possible when contract not paused.
     */
    function pause() external onlyAdmin whenNotPaused {
        _pause();
        emit Pause();
    }

    /**
     * @notice Returns to normal state
     * @dev Only possible when contract is paused.
     */
    function unpause() external onlyAdmin whenPaused {
        _unpause();
        emit Unpause();
    }
    
    function addAuthorization(address _auth) external onlyAdmin {
        isAuthorized[_auth] = true;
    }

    function revokeAuthorization(address _auth) external onlyAdmin {
        isAuthorized[_auth] = false;
    }

    /**
     * @notice Calculates the expected harvest reward from third party
     * @return Expected reward to collect in CHARM
     */
    function calculateHarvestCharmRewards() external view returns (uint256) {
        uint256 amount = IZenMaster(zenmaster).pendingCharm(0, address(this));
        amount = amount.add(available());
        uint256 currentCallFee = amount.mul(callFee).div(10000);

        return currentCallFee;
    }
    
    /**
     * @notice Calculates the expected burn amount
     * @return Expected amount to burn in CHARM
     */
    function calculateHarvestBurnAmount() external view returns (uint256) {
        uint256 amount = IZenMaster(zenmaster).pendingCharm(0, address(this));
        amount = amount.add(available());
        uint256 currentBurnFee = amount.mul(burnFee).div(10000);

        return currentBurnFee;
    }

    /**
     * @notice Calculates the total pending rewards that can be restaked
     * @return Returns total pending charm rewards
     */
    function calculateTotalPendingCharmRewards() external view returns (uint256) {
        uint256 amount = IZenMaster(zenmaster).pendingCharm(0, address(this));
        amount = amount.add(available());

        return amount;
    }

    /**
     * @notice Calculates the price per share
     */
    function getPricePerFullShare() external view returns (uint256) {
        return totalShares == 0 ? 1e18 : balanceOf().mul(1e18).div(totalShares);
    }

    /**
     * @notice Withdraws from funds from the Charm Vault
     * @param _shares: Number of shares to withdraw
     */
    function withdraw(uint256 _shares) public onlyAuthorized {
        UserInfo storage user = userInfo[msg.sender];
        require(_shares > 0, "Nothing to withdraw");
        require(_shares <= user.shares, "Withdraw amount exceeds balance");

        uint256 currentAmount = (balanceOf().mul(_shares)).div(totalShares);
        user.shares = user.shares.sub(_shares);
        totalShares = totalShares.sub(_shares);

        uint256 bal = available();
        if (bal < currentAmount) {
            uint256 balWithdraw = currentAmount.sub(bal);
            IZenMaster(zenmaster).leaveStaking(balWithdraw);
            uint256 balAfter = available();
            uint256 diff = balAfter.sub(bal);
            if (diff < balWithdraw) {
                currentAmount = bal.add(diff);
            }
        }

        if (block.timestamp < user.lastDepositedTime.add(withdrawFeePeriod)) {
            uint256 currentWithdrawFee = currentAmount.mul(withdrawFee).div(10000);
            token.safeTransfer(treasury, currentWithdrawFee);
            currentAmount = currentAmount.sub(currentWithdrawFee);
        }

        if (user.shares > 0) {
            user.charmAtLastUserAction = user.shares.mul(balanceOf()).div(totalShares);
        } else {
            user.charmAtLastUserAction = 0;
        }

        user.lastUserActionTime = block.timestamp;

        token.safeTransfer(msg.sender, currentAmount);

        emit Withdraw(msg.sender, currentAmount, _shares);
    }

    /**
     * @notice Custom logic for how much the vault allows to be borrowed
     * @dev The contract puts 100% of the tokens to work.
     */
    function available() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Calculates the total underlying tokens
     * @dev It includes tokens held by the contract and held in ZenMaster
     */
    function balanceOf() public view returns (uint256) {
        (uint256 amount, ) = IZenMaster(zenmaster).userInfo(0, address(this));
        return token.balanceOf(address(this)).add(amount);
    }

    /**
     * @notice Deposits tokens into ZenMaster to earn staking rewards
     */
    function _earn() internal {
        uint256 bal = available();
        if (bal > 0) {
            IZenMaster(zenmaster).enterStaking(bal);
        }
    }

    /**
     * @notice Checks if address is a contract
     * @dev It prevents contract from being targetted
     */
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}