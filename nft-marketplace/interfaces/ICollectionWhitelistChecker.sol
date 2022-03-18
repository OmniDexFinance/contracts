pragma solidity ^0.8.0;
 
interface ICollectionWhitelistChecker {
   function canList(uint256 _tokenId) external view returns (bool);
}
 
// File: contracts/ERC721NFTMarketV1.sol
