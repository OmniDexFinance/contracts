pragma solidity =0.5.16;

import '../OmnidexERC20.sol';

contract ERC20 is OmnidexERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
