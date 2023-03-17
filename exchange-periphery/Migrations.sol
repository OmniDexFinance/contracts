// SPDX-License-Identifier: MIT
//pragma solidity >=0.4.25 <0.7.0;
pragma solidity ^0.6.6;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }
}
