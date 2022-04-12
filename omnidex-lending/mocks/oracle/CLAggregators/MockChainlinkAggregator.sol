// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IChainlinkAggregator} from '../../../interfaces/IChainlinkAggregator.sol';
import {Ownable} from '../../../dependencies/openzeppelin/contracts/Ownable.sol';
import {SafeMath} from '../../../dependencies/openzeppelin/contracts/SafeMath.sol';

contract MockChainlinkAggregator is IChainlinkAggregator, Ownable {
  using SafeMath for uint256;

  int256 private _latestAnswer;
  uint256 private _latestRound;
  uint256 private _latestTimestamp;
  uint8 private _decimals;

  mapping(uint256 => int256) roundAnswers;
  mapping(uint256 => uint256) roundTimestamps;
  mapping(address => bool) private _sybils;

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);
  event NewRound(uint256 indexed roundId, address indexed startedBy);

  constructor(int256 initialAnswer, uint8 decimals) public {
    _latestAnswer = initialAnswer;
    _latestTimestamp = now;
    _latestRound = 0;
    _decimals = decimals;

    emit AnswerUpdated(_latestAnswer, _latestRound, _latestTimestamp);
  }

  modifier onlySybil {
    _requireWhitelistedSybil(msg.sender);
    _;
  }

  function isSybilWhitelisted(address sybil) public view returns (bool) {
    return _sybils[sybil];
  }

  function _requireWhitelistedSybil(address sybil) internal view {
    require(isSybilWhitelisted(sybil), 'INVALID_SYBIL');
  }

  function authorizeSybil(address sybil) external onlyOwner {
    _sybils[sybil] = true;
  }

  function unauthorizeSybil(address sybil) external onlyOwner {
    _sybils[sybil] = false;
  }

  function setDecimals(uint8 decimals) external onlyOwner {
    _decimals = decimals;
  }

  function decimals() external view override returns (uint8) {
    return _decimals;
  }

  function latestAnswer() external view override returns (int256) {
    return _latestAnswer;
  }

  function latestTimestamp() external view override returns (uint256) {
    return _latestTimestamp;
  }

  function latestRound() external view override returns (uint256) {
    return _latestRound;
  }

  function getAnswer(uint256 roundId) external view override returns (int256) {
    return roundAnswers[roundId];
  }

  function getTimestamp(uint256 roundId) external view override returns (uint256) {
    return roundTimestamps[roundId];
  }

  function setLatestAnswer(int256 latestAnswer) external onlySybil {
    _latestAnswer = latestAnswer;
    _latestTimestamp = now;

    emit AnswerUpdated(_latestAnswer, _latestRound, _latestTimestamp);
  }

  function createNewRound() external onlySybil {
    roundAnswers[_latestRound] = _latestAnswer;
    roundTimestamps[_latestRound] = _latestTimestamp;

    _latestRound = _latestRound.add(1);

    emit NewRound(_latestRound, msg.sender);
  }
}
