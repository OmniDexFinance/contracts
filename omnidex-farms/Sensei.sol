pragma solidity 0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';
import "./ZenMaster.sol";

// @dev The Sensei contract is a proxy contract that forwards administrative function calls to ZenMaster.
// @dev Sensei is the owner of the Zenmaster and as such has access to all owner delegated functions.
// @dev The Admin/Dev team will own Sensei and can make calls to Zenmaster owner functions via Sensei.
// @dev In order to overcome Migrator vunerabilities within the existing Zenmaster contract Sensei
// @dev will NOT forward calls to the migrator functions in Zenmaster thus making these functions 
// @dev inaccessible to all users. 
// @dev In addition Sensei will not forward calls to change the ownership of the Zenmaster thus making 
// @dev Sensei the permenant gardian of the Zenmaster.  The ownership of Sensei is transferable
// @dev but any new owner of Sensei will also NOT be able to access the migrator vunerabilities

contract Sensei is Ownable {

    mapping (address => bool) LpList; // We will chack LpList[address] to check if already in list
    
 // @dev Set the forwarding address to the currently deployed ZenMaster.
 // @dev Ownership of the ZenMaster must be transferred to this contract once this contract is deployed
    constructor(address ZenAddress) public { 
        Zen = ZenMaster(ZenAddress);
        // @dev Initialise pre existing LP addresses on deployment
        LpList[address(0x933F83735f26e51c61955b4fCA88F13fbd423A0C)] = true;
        LpList[address(0xd0D08c23d0cFd88457cDD43CaF34c16E3A29e85F)] = true;
        LpList[address(0x427E9A7bb848444a72faA3248c48F3B302429725)] = true;
        LpList[address(0x651Fcc98a348C91FDF087903c25A638a25344dFf)] = true;
        LpList[address(0xbB4555efb784cD30fC27531EEd82f7BC097D6206)] = true;
        // @dev .... add all other existing LP addresses to this list prior to deployment
    }
    ZenMaster Zen;

// @dev The functions below are the functions that will be relayed to the ZenMaster
// @dev Any other functions in the ZenMaster that are 'onlyOwner' will become innaccessible

// @dev Update farm multipliers within the ZenMaster - only callable by owner
    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {        
        Zen.updateMultiplier(multiplierNumber);
    }

// @dev Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        require(LpList[address(_lpToken)] == false, "Lp token already exists");
        LpList[address(_lpToken)] = true;
        Zen.add(_allocPoint, _lpToken, _withUpdate);
    }

    function getLpPoolExists(IBEP20 _lpToken) public view returns (bool) {
        return LpList[address(_lpToken)];
    }

    // @dev Update the given pool's CHARM allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        Zen.set(_pid, _allocPoint, _withUpdate);
    }
}