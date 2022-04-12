// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {ILendingPool} from './ILendingPool.sol';
import {IOmniDexIncentivesController} from './IOmniDexIncentivesController.sol';

/**
 * @title IInitializableOToken
 * @notice Interface for the initialize function on OToken
 * @author OmniDex
 **/
interface IInitializableOToken {
  /**
   * @dev Emitted when an oToken is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated lending pool
   * @param treasury The address of the treasury
   * @param incentivesController The address of the incentives controller for this oToken
   * @param oTokenDecimals the decimals of the underlying
   * @param oTokenName the name of the oToken
   * @param oTokenSymbol the symbol of the oToken
   * @param params A set of encoded parameters for additional initialization
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address treasury,
    address incentivesController,
    uint8 oTokenDecimals,
    string oTokenName,
    string oTokenSymbol,
    bytes params
  );

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
  ) external;
}
