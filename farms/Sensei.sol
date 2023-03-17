pragma solidity 0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
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
    constructor(address ZenAddress, address[] memory initialDelegates) public { 
        Zen = ZenMaster(ZenAddress);
        // @dev Initialise pre existing LP addresses on deployment
        LpList[address(0x933F83735f26e51c61955b4fCA88F13fbd423A0C)] = true; // CHARM-TLOS
        LpList[address(0xC72ca4D9Ef358E1d8989e36dF9dFA28378137D20)] = true; // KARMA-TLOS
        LpList[address(0xd0D08c23d0cFd88457cDD43CaF34c16E3A29e85F)] = true; // TLOS-ETH
        LpList[address(0x427E9A7bb848444a72faA3248c48F3B302429725)] = true; // wBTC-TLOS
        LpList[address(0x651Fcc98a348C91FDF087903c25A638a25344dFf)] = true; // TLOS-USDC
        LpList[address(0xE320E5c4260c7186Fdb0Ea782A3C802736da743F)] = true; // TLOS-DOUGE
        LpList[address(0x01623ebcBB1109E968e20570d2d41E61cf86F6d0)] = true; // DOUGE-CHARM
        LpList[address(0xbB4555efb784cD30fC27531EEd82f7BC097D6206)] = true; // CHARM-USDC
        LpList[address(0x8805F519663E47aBd6adbA4303639f69e51fd112)] = true; // USDC-USDT
        LpList[address(0xE2dE6566717fF3b1b1e988353E1f63dA0BD9E6f8)] = true; // CHARM-ETH
        LpList[address(0x63276BDab3443993adc45Eed3C6105B07338D648)] = true; // ELK-TLOS
        LpList[address(0x72801E883EBF8548D0bF9BcF149DF72D84542448)] = true; // BNB-TLOS
        LpList[address(0x5b9447EF36abf518cca729bF08E8D72b24a69BDF)] = true; // FTM-TLOS
        LpList[address(0xb812270599DB74d066578Bd940A95728bFc6988B)] = true; // AVAX-CHARM
        LpList[address(0x7B90a6355FAc6F0b928aa815335b5Aa42dD2749e)] = true; // MATIC-TLOS
        LpList[address(0xa6Dc4d4d8fa2c6f8667B096C368e246718982787)] = true; // AVAX-TLOS
        LpList[address(0x14c5ce09A3a313C78E5a4354F88a97B2414c39e1)] = true; // DMMY-TLOS
        LpList[address(0xE36aaF76f4d769799C29ebB63f35023239C28B56)] = true; // ONE-TLOS
        LpList[address(0xC4dC3ce0f4D377DE26b575ED4E2501245d04945f)] = true; // KARMA-CHARM
        LpList[address(0xa2AB1530F57Ed920027c9D1d66eE9582E6cd7913)] = true; // KARMA-ELK
        LpList[address(0xf8EB0771d72db674f4FDEe54434080d0bdd0cB41)] = true; // KARMA-DOUGE
        LpList[address(0x76Bf9208b92C75c94A5723f4a7343C26BB5739B8)] = true; // KARMA-DMMY


        // Now initialise variables for the timelock and multisig
        require(initialDelegates.length  > minSignatures && initialDelegates.length <= MAX_DELEGATES, " Incompatible number of signatories");
        for (uint i = 0; i < initialDelegates.length; i++) {  // authorise the intial delegates to sign
            require(isAuthorized[initialDelegates[i]] == false, "Duplicate address not allowed");
            isAuthorized[initialDelegates[i]] = true;
        }
        totalDelegates = initialDelegates.length;
        isAdmin[msg.sender] = true;
    }
    ZenMaster Zen;

// @dev The functions below are the functions that will be relayed to the ZenMaster
// @dev Any other functions in the ZenMaster that are 'onlyOwner' will become innaccessible

// @dev Add a new lp to the pool. Can only be called by admin once signed and after timelock.
    function add() public onlyAdmin notLocked(Functions.ADD) isSigned(Functions.ADD){
        require(LpList[address(timelock[Functions.ADD].params.lpToken)] == false, "Lp token already exists");
        LpList[address(timelock[Functions.ADD].params.lpToken)] = true;
        Zen.add(timelock[Functions.ADD].params.poolAllocationPts,
                timelock[Functions.ADD].params.lpToken,
                timelock[Functions.ADD].params.withUpdateAll);
    }

    function getLpPoolExists(IBEP20 _lpToken) public view returns (bool) {
        return LpList[address(_lpToken)];
    }

    // @dev Update the given pool's CHARM allocation point. Can only be called by admin once signed and after timelock.
    function set() public onlyAdmin notLocked(Functions.SET) isSigned(Functions.SET) {
        Zen.set(timelock[Functions.SET].params.pid, 
                timelock[Functions.SET].params.poolAllocationPts, 
                timelock[Functions.SET].params.withUpdateAll);
        clearRequest(Functions.SET);
    }

    function getZenMasterAddress() public view returns (address) {
        return address(Zen);
    }

//******************* Combined Timelock & Multisig functionality ************************************************
// @Notice Step 1 - Auth user requests to unlock specified function passing in future value settings
// @Notice Step 2 - Timelock initiates & starts to time down
// @Notice Step 3 - When required authorised users can sign request 
// @Notice step 4 - Request is enabled once timelock has expired and, if required, sufficient signatures recieved
// @Notice step 5 - request is reset after it is actioned or expires after grace period

    enum Functions { ADD, SET, SETDELAY, UPDATESIGS, ADDAUTH, REVOKEAUTH, ADDADMIN, REVOKEADMIN } 

    event NewMinSignatures(uint indexed newMinSignatures);
    event NewDelay(uint indexed newDelay);
    event NewUnlockRequest(Functions indexed newUnlockRequest);   
    event NewLockRequest(Functions indexed newUnLockRequest);    
    event NewAuthorization(address indexed newAuth);
    event NewRevokeAuthorization(address indexed newRevoke);
    
    uint public constant MIN_DELEGATES = 2;
    uint public constant MAX_DELEGATES = 10;
    uint public constant GRACE_PERIOD = 14 days;      
    uint public constant MINIMUM_DELAY = 48 hours;
    uint public constant MAXIMUM_DELAY = 30 days;  
    uint public delay = MINIMUM_DELAY;
    uint public totalDelegates;
    uint public minSignatures =MIN_DELEGATES;
    struct fnParams {               // parameters which will be used in function calls
        uint256 poolAllocationPts;
        uint256 pid;
        IBEP20 lpToken;
        bool withUpdateAll;
        address delegateAddress;
    }
    struct request {                // stored info relating to action request
        uint delay;
        address[] signatures;
        fnParams params;
    }   
    mapping(Functions => request) timelock;
    mapping(address => bool) isAuthorized; // set of addresses that can authorise changes
    mapping(address => bool) isAdmin; // set of addresses that can execute authorised changes

    modifier notLocked(Functions _fn) {
        require(timelock[_fn].delay != 0 && timelock[_fn].delay <= block.timestamp, "Function is timelocked");
        require((timelock[_fn].delay + GRACE_PERIOD) >= block.timestamp, "Function execution window expired");
     _;}
    modifier isSigned(Functions _fn) {
        require(timelock[_fn].signatures.length >= minSignatures, "Insufficient signatures");        
     _;}
    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender], "auth: FORBIDDEN only authorised users");
    _;}
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "auth: FORBIDDEN only admin");
    _;}

    function isApprovedToSign(address _user) external view returns (bool) {      
        return isAuthorized[_user];
    }
    function isApprovedAdmin(address _user) external view returns (bool) {      
        return isAdmin[_user];
    }
    function getTimeLock(Functions _func) external view 
            returns (uint, uint256, uint256, IBEP20, address) {   
        return (timelock[_func].delay, timelock[_func].params.poolAllocationPts, timelock[_func].params.pid,
                timelock[_func].params.lpToken,timelock[_func].params.delegateAddress);
    }

    function updateMinSignatures(uint _newMin) external onlyOwner notLocked(Functions.UPDATESIGS) isSigned(Functions.UPDATESIGS) {
        require(_newMin >= MIN_DELEGATES && _newMin < MAX_DELEGATES && _newMin < totalDelegates, "Incompatible number of signatories");
        minSignatures = _newMin;
        clearRequest(Functions.UPDATESIGS);
        emit NewMinSignatures(minSignatures);
    }

    function addAuthorization() external onlyAdmin notLocked(Functions.ADDAUTH) isSigned(Functions.ADDAUTH) {
        require(totalDelegates < minSignatures+2 && totalDelegates < MAX_DELEGATES, "Too many delegates");
        require(isAuthorized[timelock[Functions.ADDAUTH].params.delegateAddress] == false, "Delegate already authorised");
        isAuthorized[timelock[Functions.ADDAUTH].params.delegateAddress] = true;
        totalDelegates = totalDelegates + 1;
        emit NewAuthorization(timelock[Functions.ADDAUTH].params.delegateAddress);
    }
    function revokeAuthorization() external onlyAdmin notLocked(Functions.REVOKEAUTH) isSigned(Functions.REVOKEAUTH){
        require(totalDelegates > minSignatures + 1, "Insufficient delegates");
        require(isAuthorized[timelock[Functions.REVOKEAUTH].params.delegateAddress] == true, "Delegate not yet authorised");
        isAuthorized[timelock[Functions.REVOKEAUTH].params.delegateAddress] = false;
        totalDelegates = totalDelegates - 1;
        emit NewRevokeAuthorization(timelock[Functions.REVOKEAUTH].params.delegateAddress);
    }

    function addAdmin() external onlyOwner notLocked(Functions.ADDADMIN) {        
        isAdmin[timelock[Functions.ADDADMIN].params.delegateAddress] = true;
    }
    function revokeAdmin() external onlyOwner notLocked(Functions.REVOKEADMIN) {
        require(timelock[Functions.REVOKEADMIN].params.delegateAddress != msg.sender, "Cannot revoke yourself");
        isAdmin[timelock[Functions.REVOKEADMIN].params.delegateAddress] = false;
    }

    function setDelay(uint delay_) public onlyOwner notLocked(Functions.SETDELAY) {        
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;
        clearRequest(Functions.SETDELAY);
        emit NewDelay(delay);
    }

    //unlock timelock
    function unlockRequest(Functions _fn, uint256 poolAllocationPts_, uint256 pid_,
        IBEP20 lpToken_, bool withUpdateAll_, address delegateAddress_) public onlyAuthorized {
        timelock[_fn].delay = block.timestamp + delay;
        timelock[_fn].signatures = new address[](0);  // reset any existing signatures for new request
        timelock[_fn].params.poolAllocationPts = poolAllocationPts_;
        timelock[_fn].params.pid = pid_;
        timelock[_fn].params.lpToken = lpToken_;
        timelock[_fn].params.withUpdateAll = withUpdateAll_;
        timelock[_fn].params.delegateAddress = delegateAddress_;
        emit NewUnlockRequest(_fn);
    }
  
    //lock timelock
    function lockRequest(Functions _fn) public onlyOwner {
        clearRequest(_fn);
        emit NewLockRequest(_fn);
    }

    function clearRequest(Functions _fn) internal {
        timelock[_fn].delay = 0;                        // reset delay counter for this function
        delete timelock[_fn].params;                    // reset input parameters  
        timelock[_fn].signatures = new address[](0);    // reset existing signatures for this function
    }

    function Sign(Functions _fn)  public onlyAuthorized {
        // first check to see if the authorized user has already signed
        for (uint i = 0; i < timelock[_fn].signatures.length; i++) {
            require(timelock[_fn].signatures[i] != msg.sender, "Delegate has already signed");
        }
        timelock[_fn].signatures.push(msg.sender); // record that sender has signed in array
    }
  
    function getNumSignatures(Functions _fn) external view returns (uint256) {      
        return timelock[_fn].signatures.length;
    }
}
