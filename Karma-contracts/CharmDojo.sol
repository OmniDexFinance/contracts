// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';
import './interfaces/ICharmVault.sol';

// CharmDojo is the place where Charm's live to create Karma.
// This contract handles swapping to and from Karma, OmniDex's staking token.
contract CharmDojo is ERC20("Charm Dojo", "Karma") {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    IERC20 public charm;
    ICharmVault public immutable charmVault;
    address public admin;
    address public treasury;

    // Define the Charm token contract
    constructor(IERC20 _charm, ICharmVault _charmVault) public {
        charm = _charm;
        charmVault = _charmVault;
        
        // Infinite approve
        IERC20(_charm).safeApprove(address(_charmVault), uint256(-1));
        admin = msg.sender;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "admin: FORBIDDEN");
        _;
    }
    
    function setAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Cannot be zero address");
        admin = _admin;
    }
    
    function setTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), "Cannot be zero address");
        treasury = _treasury;
    }

    // Locks Charm and mints Karma
    function deposit(uint256 _amount) public {
        // Gets the amount of Charm locked in the contract and vault
        uint256 totalCharm = balanceOfCharm();
        // Gets the amount of Karma in existence
        uint256 totalShares = totalSupply();
        // If no Karma exists, mint it 1:1 to the amount put in
        // Lock the Charm in the contract
        charm.transferFrom(msg.sender, address(this), _amount);
        
        if (totalShares == 0 || totalCharm == 0) {
            mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of Karma the Charm is worth. The ratio will change overtime, as Karma is burned/minted and Charm deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalCharm);
            mint(msg.sender, what);
        }
        
        ICharmVault(charmVault).deposit(_amount);
    }

    // Unlocks the staked + gained Charm and burns Karma
    function withdraw(uint256 _share) public {
        // Gets the amount of Karma in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Charm the Karma is worth
        uint256 what = _share.mul(balanceOfCharm()).div(totalShares);
        burn(msg.sender, _share);
        
        ICharmVault(charmVault).withdrawAll();
        charm.transfer(msg.sender, what);
        
        uint256 currentCharmBalance = charm.balanceOf(address(this));
        if(currentCharmBalance > 0) {
            ICharmVault(charmVault).deposit(currentCharmBalance);
        }
    }
    
    // returns the total amount of Charm held in the contract and vault
    function balanceOfCharm() public view returns (uint256) {
        return charm.balanceOf(address(this)).add(ICharmVault(charmVault).balanceOf());
    }

    // returns the total amount of Charm an address has in the contract including fees earned
    function charmBalance(address _account) external view returns (uint256 charmAmount_) {
        uint256 karmaAmount = balanceOf(_account);
        uint256 totalKarma = totalSupply();
        
        if(totalKarma == 0 || karmaAmount == 0) {
            charmAmount_ = 0;
        } else {
            charmAmount_ = karmaAmount.mul(balanceOfCharm()).div(totalKarma);
        }
    }

    // returns how much Charm someone gets for redeeming Karma
    function karmaForCharm(uint256 _karmaAmount) external view returns (uint256 charmAmount_) {
        uint256 totalCharm = balanceOfCharm();
        uint256 totalKarma = totalSupply();
        
        if(totalKarma == 0 || totalCharm == 0) {
            charmAmount_ = _karmaAmount;
        } else {
            charmAmount_ = _karmaAmount.mul(balanceOfCharm()).div(totalKarma);
        }
    }

    // returns how much Karma someone gets for depositing Charm
    function charmForKarma(uint256 _charmAmount) external view returns (uint256 karmaAmount_) {
        uint256 totalCharm = balanceOfCharm();
        uint256 totalKarma = totalSupply();
        if (totalKarma == 0 || totalCharm == 0) {
            karmaAmount_ = _charmAmount;
        }
        else {
            karmaAmount_ = _charmAmount.mul(totalKarma).div(totalCharm);
        }
    }
    
    // proxy call to harvest on vault
    function harvest() external {
        ICharmVault(charmVault).harvest(msg.sender);
    }
    
    // proxy call to calculate the expected harvest reward from third party
    function calculateHarvestCharmRewards() external view returns (uint256) {
        return ICharmVault(charmVault).calculateHarvestCharmRewards();
    }

    // proxy call to calculate the total pending rewards that can be restaked
    function calculateTotalPendingCharmRewards() external view returns (uint256) {
        return ICharmVault(charmVault).calculateTotalPendingCharmRewards();
    }
    
    // proxy call to withdraw all charms from vault
    function withdrawAll() external onlyAdmin {
        require(treasury != address(0), "withdrawAll: Treasury Not Set");
        require(totalSupply() == 0, "withdrawAll: Outstanding Shares");
        
        charm.transfer(treasury, charm.balanceOf(address(this)));
    }

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    // A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    
    function burn(address _from, uint256 _amount) private {
        _burn(_from, _amount);
        _moveDelegates(_delegates[_from], address(0), _amount);
    }

    function mint(address recipient, uint256 _amount) private {
        _mint(recipient, _amount);

        _initDelegates(recipient);

        _moveDelegates(address(0), _delegates[recipient], _amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) 
    public virtual override returns (bool)
    {
        bool result = super.transferFrom(sender, recipient, amount); // Call parent hook

        _initDelegates(recipient);

        _moveDelegates(_delegates[sender], _delegates[recipient], amount);

        return result;
    }

    function transfer(address recipient, uint256 amount) 
    public virtual override returns (bool)
    {
        bool result = super.transfer(recipient, amount); // Call parent hook

        _initDelegates(recipient);

        _moveDelegates(_delegates[_msgSender()], _delegates[recipient], amount);

        return result;
    }

    // initialize delegates mapping of recipient if not already
    function _initDelegates(address recipient) internal {
        if(_delegates[recipient] == address(0)) {
            _delegates[recipient] = recipient;
        }
    }

    /**
     * @param delegator The address to get delegates for
     */
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        return _delegates[delegator];
    }

   /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "CHARM::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "CHARM::delegateBySig: invalid nonce");
        require(block.timestamp <= expiry, "CHARM::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "CHARM::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
        internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying Charms (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint32 blockNumber = safe32(block.number, "CHARM::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

}