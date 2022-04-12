// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';
import {SafeERC20} from '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {ILendingPool} from '../../interfaces/ILendingPool.sol';
import {IOToken} from '../../interfaces/IOToken.sol';
import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {
  VersionedInitializable
} from '../libraries/omnidex-upgradeability/VersionedInitializable.sol';
import {IncentivizedERC20} from './IncentivizedERC20.sol';
import {IOmniDexIncentivesController} from '../../interfaces/IOmniDexIncentivesController.sol';

/**
 * @title OmniDex ERC20 OToken
 * @dev Implementation of the interest bearing token for the OmniDex protocol
 * @author OmniDex
 */
contract OToken is
  VersionedInitializable,
  IncentivizedERC20('OTOKEN_IMPL', 'OTOKEN_IMPL', 0),
  IOToken
{
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  bytes public constant EIP712_REVISION = bytes('1');
  bytes32 internal constant EIP712_DOMAIN =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');
  bytes32 public constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  uint256 public constant OTOKEN_REVISION = 0x1;

  /// @dev owner => next valid nonce to submit with permit()
  mapping(address => uint256) public _nonces;

  bytes32 public DOMAIN_SEPARATOR;

  ILendingPool internal _pool;
  address internal _treasury;
  address internal _karmaFeeHolder;
  address internal _team1;
  address internal _team2;
  address internal _team3;
  address internal _underlyingAsset;
  IOmniDexIncentivesController internal _incentivesController;

  modifier onlyLendingPool {
    require(_msgSender() == address(_pool), Errors.CT_CALLER_MUST_BE_LENDING_POOL);
    _;
  }

  modifier onlyCurrentTreasury {
    require(_msgSender() == _treasury, 'Only Current Treasury');
    _;
  }

  modifier onlyCurrentKarmaFeeHolder {
    require(_msgSender() == _karmaFeeHolder, 'Only Current Karma Fee Holder');
    _;
  }

  modifier onlyCurrentTeam1 {
    require(_msgSender() == _team1, 'Only Current Team 1');
    _;
  }

  modifier onlyCurrentTeam2 {
    require(_msgSender() == _team2, 'Only Current Team 2');
    _;
  }

  modifier onlyCurrentTeam3 {
    require(_msgSender() == _team3, 'Only Current Team 3');
    _;
  }

  function setTreasury(address newAddress) external onlyCurrentTreasury {
    _treasury = newAddress;
  }

  function getTreasury() public view returns (address) {
    return _treasury;
  }

  function setKarmaFeeHolder(address newAddress) external onlyCurrentKarmaFeeHolder {
    _karmaFeeHolder = newAddress;
  }

  function getKarmaFeeHolder() public view returns (address) {
    return _karmaFeeHolder;
  }

  function setTeam1(address newAddress) external onlyCurrentTeam1 {
    _team1 = newAddress;
  }

  function setTeam2(address newAddress) external onlyCurrentTeam2 {
    _team2 = newAddress;
  }

  function setTeam3(address newAddress) external onlyCurrentTeam3 {
    _team3 = newAddress;
  }

  function getRevision() internal pure virtual override returns (uint256) {
    return OTOKEN_REVISION;
  }

  /**
   * @dev Initializes the oToken
   * @param pool The address of the lending pool where this oToken will be used
   * @param treasury The address of the OmniDex treasury, receiving the fees on this oToken
   * @param underlyingAsset The address of the underlying asset of this oToken (E.g. WETH for aWETH)
   * @param incentivesController The smart contract managing potential incentives distribution
   * @param oTokenDecimals The decimals of the oToken, same as the underlying asset's
   * @param oTokenName The name of the oToken
   * @param oTokenSymbol The symbol of the oToken
   */
  function initialize(
    ILendingPool pool,
    address treasury,
    address underlyingAsset,
    IOmniDexIncentivesController incentivesController,
    uint8 oTokenDecimals,
    string calldata oTokenName,
    string calldata oTokenSymbol,
    bytes calldata params
  ) external override initializer {
    uint256 chainId;

    //solium-disable-next-line
    assembly {
      chainId := chainid()
    }

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(oTokenName)),
        keccak256(EIP712_REVISION),
        chainId,
        address(this)
      )
    );

    _setName(oTokenName);
    _setSymbol(oTokenSymbol);
    _setDecimals(oTokenDecimals);

    _pool = pool;
    _treasury = treasury;
    _underlyingAsset = underlyingAsset;
    _incentivesController = incentivesController;

    _karmaFeeHolder = 0x9892F867F0E3d54cf9EdA66Cf5886bd84D973e2f;
    _team1 = 0xBd6721C192547cba2Bc62027D44Ce0FE085f214f;
    _team2 = 0xe7209d65c5BB05Ddf799b20fF0EC09E691FC3f11;
    _team3 = 0x68f3Ed374Ab786A5b8eA959c89C4F06e83f52FC1;

    emit Initialized(
      underlyingAsset,
      address(pool),
      treasury,
      address(incentivesController),
      oTokenDecimals,
      oTokenName,
      oTokenSymbol,
      params
    );
  }

  /**
   * @dev Burns oTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
   * - Only callable by the LendingPool, as extra state updates there need to be managed
   * @param user The owner of the oTokens, getting them burned
   * @param receiverOfUnderlying The address that will receive the underlying
   * @param amount The amount being burned
   * @param index The new liquidity index of the reserve
   **/
  function burn(
    address user,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool {
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled != 0, Errors.CT_INVALID_BURN_AMOUNT);
    _burn(user, amountScaled);

    IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);

    emit Transfer(user, address(0), amount);
    emit Burn(user, receiverOfUnderlying, amount, index);
  }

  /**
   * @dev Mints `amount` oTokens to `user`
   * - Only callable by the LendingPool, as extra state updates there need to be managed
   * @param user The address receiving the minted tokens
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   * @return `true` if the the previous balance of the user was 0
   */
  function mint(
    address user,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool returns (bool) {
    uint256 previousBalance = super.balanceOf(user);

    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled != 0, Errors.CT_INVALID_MINT_AMOUNT);
    _mint(user, amountScaled);

    emit Transfer(address(0), user, amount);
    emit Mint(user, amount, index);

    return previousBalance == 0;
  }

  /**
   * @dev Mints oTokens to the reserve treasury
   * - Only callable by the LendingPool
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   */
  function mintToTreasury(uint256 amount, uint256 index) external override onlyLendingPool {
    if (amount == 0) {
      return;
    }

    address treasury = _treasury;
    address karmaFeeHolder = _karmaFeeHolder;
    address team1 = _team1;
    address team2 = _team2;
    address team3 = _team3;

    uint256 treasuryAmount = amount;
    uint256 karmaFeeAmount = treasuryAmount.mul(80).div(100);
    uint256 teamAmount = treasuryAmount.mul(10).div(100);
    uint256 teamSplitAmount = teamAmount.div(3);

    treasuryAmount = treasuryAmount.sub(karmaFeeAmount);
    treasuryAmount = treasuryAmount.sub(teamAmount);

    // Compared to the normal mint, we don't check for rounding errors.
    // The amount to mint can easily be very small since it is a fraction of the interest ccrued.
    // In that case, the treasury will experience a (very small) loss, but it
    // wont cause potentially valid transactions to fail.
    _mint(treasury, treasuryAmount.rayDiv(index));
    _mint(karmaFeeHolder, karmaFeeAmount.rayDiv(index));
    _mint(team1, teamSplitAmount.rayDiv(index));
    _mint(team2, teamSplitAmount.rayDiv(index));
    _mint(team3, teamSplitAmount.rayDiv(index));

    emit Transfer(address(0), treasury, treasuryAmount);
    emit Mint(treasury, amount, index);
  }

  /**
   * @dev Transfers oTokens in the event of a borrow being liquidated, in case the liquidators reclaims the oToken
   * - Only callable by the LendingPool
   * @param from The address getting liquidated, current owner of the oTokens
   * @param to The recipient
   * @param value The amount of tokens getting transferred
   **/
  function transferOnLiquidation(
    address from,
    address to,
    uint256 value
  ) external override onlyLendingPool {
    // Being a normal transfer, the Transfer() and BalanceTransfer() are emitted
    // so no need to emit a specific event here
    _transfer(from, to, value, false);

    emit Transfer(from, to, value);
  }

  /**
   * @dev Calculates the balance of the user: principal balance + interest generated by the principal
   * @param user The user whose balance is calculated
   * @return The balance of the user
   **/
  function balanceOf(address user)
    public
    view
    override(IncentivizedERC20, IERC20)
    returns (uint256)
  {
    return super.balanceOf(user).rayMul(_pool.getReserveNormalizedIncome(_underlyingAsset));
  }

  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   **/
  function scaledBalanceOf(address user) external view override returns (uint256) {
    return super.balanceOf(user);
  }

  /**
   * @dev Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled balance and the scaled total supply
   **/
  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    return (super.balanceOf(user), super.totalSupply());
  }

  /**
   * @dev calculates the total supply of the specific oToken
   * since the balance of every single user increases over time, the total supply
   * does that too.
   * @return the current total supply
   **/
  function totalSupply() public view override(IncentivizedERC20, IERC20) returns (uint256) {
    uint256 currentSupplyScaled = super.totalSupply();

    if (currentSupplyScaled == 0) {
      return 0;
    }

    return currentSupplyScaled.rayMul(_pool.getReserveNormalizedIncome(_underlyingAsset));
  }

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return the scaled total supply
   **/
  function scaledTotalSupply() public view virtual override returns (uint256) {
    return super.totalSupply();
  }

  /**
   * @dev Returns the address of the OmniDex treasury, receiving the fees on this oToken
   **/
  function RESERVE_TREASURY_ADDRESS() public view returns (address) {
    return _treasury;
  }

  /**
   * @dev Returns the address of the underlying asset of this oToken (E.g. WETH for aWETH)
   **/
  function UNDERLYING_ASSET_ADDRESS() public view override returns (address) {
    return _underlyingAsset;
  }

  /**
   * @dev Returns the address of the lending pool where this oToken is used
   **/
  function POOL() public view returns (ILendingPool) {
    return _pool;
  }

  /**
   * @dev For internal usage in the logic of the parent contract IncentivizedERC20
   **/
  function _getIncentivesController()
    internal
    view
    override
    returns (IOmniDexIncentivesController)
  {
    return _incentivesController;
  }

  /**
   * @dev Returns the address of the incentives controller contract
   **/
  function getIncentivesController() external view override returns (IOmniDexIncentivesController) {
    return _getIncentivesController();
  }

  function setIncentivesController(IOmniDexIncentivesController incentivesController)
    external
    override
    onlyCurrentTreasury
  {
    _incentivesController = incentivesController;
  }

  /**
   * @dev Transfers the underlying asset to `target`. Used by the LendingPool to transfer
   * assets in borrow(), withdraw() and flashLoan()
   * @param target The recipient of the oTokens
   * @param amount The amount getting transferred
   * @return The amount transferred
   **/
  function transferUnderlyingTo(address target, uint256 amount)
    external
    override
    onlyLendingPool
    returns (uint256)
  {
    IERC20(_underlyingAsset).safeTransfer(target, amount);
    return amount;
  }

  /**
   * @dev Invoked to execute actions on the oToken side after a repayment.
   * @param user The user executing the repayment
   * @param amount The amount getting repaid
   **/
  function handleRepayment(address user, uint256 amount) external override onlyLendingPool {}

  /**
   * @dev implements the permit function as for
   * https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param owner The owner of the funds
   * @param spender The spender
   * @param value The amount
   * @param deadline The deadline timestamp, type(uint256).max for max deadline
   * @param v Signature param
   * @param s Signature param
   * @param r Signature param
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(owner != address(0), 'INVALID_OWNER');
    //solium-disable-next-line
    require(block.timestamp <= deadline, 'INVALID_EXPIRATION');
    uint256 currentValidNonce = _nonces[owner];
    bytes32 digest =
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          DOMAIN_SEPARATOR,
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
        )
      );
    require(owner == ecrecover(digest, v, r, s), 'INVALID_SIGNATURE');
    _nonces[owner] = currentValidNonce.add(1);
    _approve(owner, spender, value);
  }

  /**
   * @dev Transfers the oTokens between two users. Validates the transfer
   * (ie checks for valid HF after the transfer) if required
   * @param from The source address
   * @param to The destination address
   * @param amount The amount getting transferred
   * @param validate `true` if the transfer needs to be validated
   **/
  function _transfer(
    address from,
    address to,
    uint256 amount,
    bool validate
  ) internal {
    address underlyingAsset = _underlyingAsset;
    ILendingPool pool = _pool;

    uint256 index = pool.getReserveNormalizedIncome(underlyingAsset);

    uint256 fromBalanceBefore = super.balanceOf(from).rayMul(index);
    uint256 toBalanceBefore = super.balanceOf(to).rayMul(index);

    super._transfer(from, to, amount.rayDiv(index));

    if (validate) {
      pool.finalizeTransfer(underlyingAsset, from, to, amount, fromBalanceBefore, toBalanceBefore);
    }

    emit BalanceTransfer(from, to, amount, index);
  }

  /**
   * @dev Overrides the parent _transfer to force validated transfer() and transferFrom()
   * @param from The source address
   * @param to The destination address
   * @param amount The amount getting transferred
   **/
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    _transfer(from, to, amount, true);
  }
}
