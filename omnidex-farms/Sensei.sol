pragma solidity 0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';
import "./ZenMaster.sol";

// The Sensei contract is a proxy contract that forwards administrative function calls to ZenMaster.
// Sensei is the owner of the Zenmaster and as such has access to all owner delegated functions.
// The Admin/Dev team will own Sensei and can make calls to Zenmaster owner functions via Sensei.
// In order to overcome Migrator vunerabilities within the existing Zenmaster contract Sensei
// will NOT forward calls to the migrator functions in Zenmaster thus making these functions 
// inaccessible to all users. 
// In addition Sensei will not forward calls to change the ownership of the Zenmaster thus making 
// Sensei the permenant gardian of the Zenmaster.  The ownership of Sensei is transferable
// but any new owner of Sensei will also NOT be able to access the migrator vunerabilities

contract Sensei is Ownable {

 // Set the forwarding address to the currently deployed ZenMaster.
 // Ownership of the ZenMaster must be transferred to this contract once this contract is deployed
    constructor(address a) public { 
        Zen = ZenMaster(a);
    }
    ZenMaster Zen;

// The functions below are the functions that will be relayed to the ZenMaster
// Any other functions in the ZenMaster that are 'onlyOwner' will become innaccessible

// Update farm multipliers within the ZenMaster - only callable by owner
    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {        
        Zen.updateMultiplier(multiplierNumber);
    }

// Add a new lp to the pool. Can only be called by the owner.
// XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        Zen.add(_allocPoint, _lpToken, _withUpdate);
    }

    // Update the given pool's CHARM allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        Zen.set(_pid, _allocPoint, _withUpdate);
    }
}