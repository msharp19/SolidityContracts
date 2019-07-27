pragma solidity ^0.5.9;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256){
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Ownable {
  address payable public owner;
  address payable public potentialNewOwner;
 
  event OwnershipTransferred(address payable indexed _from, address payable indexed _to);

  constructor() internal {
    owner = msg.sender;
  }
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  function transferOwnership(address payable _newOwner) external onlyOwner {
    potentialNewOwner = _newOwner;
  }
  function acceptOwnership() external {
    require(msg.sender == potentialNewOwner);
    emit OwnershipTransferred(owner, potentialNewOwner);
    owner = potentialNewOwner;
  }
}

contract CircuitBreaker is Ownable {
    bool public inLockdown;

    constructor () internal {
        inLockdown = false;
    }
    modifier outOfLockdown() {
        require(inLockdown == false);
        _;
    }
    function updateLockdownState(bool state) public{
        inLockdown = state;
    }
}

contract ERC20Interface {
    uint256 public totalSupply;
    function balanceOf(address _owner) public view returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 indexed _value);
}

contract ERC20 is ERC20Interface {
  using SafeMath for uint256;

  mapping(address => uint256) public balances;
  mapping (address => mapping (address => uint256)) allowed;

  function balanceOf(address _owner) view public returns (uint256 balance) {
    return balances[_owner];
  }
  function transfer(address _to, uint256 _value) public returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    uint256 _allowance = allowed[_from][msg.sender];
    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }
  function approve(address _spender, uint256 _value) public returns (bool) {
    require((_value == 0) || (allowed[msg.sender][_spender] == 0));
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }
  function allowance(address _owner, address _spender) view public returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }
}

contract MintableToken is ERC20{
  function mintToken(address target, uint256 mintedAmount) public returns(bool){
	balances[target] = balances[target].add(mintedAmount);
	totalSupply = totalSupply.add(mintedAmount);
	emit Transfer(address(0), address(this), mintedAmount);
	emit Transfer(address(this), target, mintedAmount);
	return true;
  }
}

contract RecoverableToken is ERC20, Ownable {
  constructor() public {}

  function recoverTokens(ERC20 token) public {
    token.transfer(owner, tokensToBeReturned(token));
  }
  function tokensToBeReturned(ERC20 token) public view returns (uint256) {
    return token.balanceOf(address(this));
  }
}

contract BurnableToken is ERC20 {
  address public BURN_ADDRESS;

  event Burned(address indexed burner, uint256 indexed burnedAmount);
 
  function burn(uint256 burnAmount) public {
    address burner = msg.sender;
    balances[burner] = balances[burner].sub(burnAmount);
    totalSupply = totalSupply.sub(burnAmount);
    emit Burned(burner, burnAmount);
    emit Transfer(burner, BURN_ADDRESS, burnAmount);
  }
}

contract ReentrancyGuard {   
    uint256 private _guardCounter;

    constructor () internal {
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter);
    } 
}

contract StreamerToken is RecoverableToken, BurnableToken, MintableToken, CircuitBreaker, ReentrancyGuard { 
  string public name;
  string public symbol;
  uint256 public decimals;
  address payable public adminWallet;
  uint256 public rate;
  uint256 public weiRaised;
  uint256 private shareMultiplier;
  address payable private zombieCashWallet;
  uint256 public deployedAt;
  
  event ContractAdminShareLog(address indexed creator, uint256 contractAmount, uint256 adminAmount);
  event FundSplit(address indexed adminAddress, uint256 adminAmount, address indexed zombieAddress, uint256 zombieCash);

  constructor(address payable _owner, uint256 _totalTokensToMint, string memory _name, string memory _symbol, uint256 _rate, 
    uint256 _shareMultiplier, address payable _zombieCashWallet, uint256 _percentToKeepInContract) public {
    //Checks
    require(_rate > 0);
    require(_owner != address(0));
    require(_totalTokensToMint > 0);
    require(_shareMultiplier > 0);
    require(_zombieCashWallet != address(0));
    require(_percentToKeepInContract <= 100);
    //Sets
    name = _name;
    symbol = _symbol;
    totalSupply = _totalTokensToMint;
    decimals = 18;
    adminWallet = _owner;
    rate = _rate;
    weiRaised = 0;
    shareMultiplier = _shareMultiplier;
    zombieCashWallet = _zombieCashWallet;
    deployedAt = now;
    //Share
    uint256 contractShare = totalSupply.div(100).mul(_percentToKeepInContract);
    uint256 adminShare = totalSupply.sub(contractShare);
    balances[msg.sender] = adminShare;
    balances[address(this)] = contractShare;
    //Log
    emit ContractAdminShareLog(msg.sender, contractShare, adminShare);
  }
  
  function() payable external outOfLockdown nonReentrant {
    uint256 weiAmount = msg.value;
    _preValidatePurchase(msg.sender, weiAmount);
    uint256 tokens = _getTokenAmount(weiAmount);
    transferFromAdmin(msg.sender, tokens);
    _forwardFunds();
    weiRaised = weiRaised.add(weiAmount);
  }
 
  function transferFromAdmin(address _to, uint256 _value) private {
    balances[address(this)] = balances[address(this)].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(address(this), _to, _value);
  }
  
  function transfer(address _to, uint256 _value) public outOfLockdown returns (bool success){
    return super.transfer(_to, _value);
  }
  
  function transferFrom(address _from, address _to, uint256 _value) public outOfLockdown returns (bool success){
    return super.transferFrom(_from, _to, _value);
  }
  
  function multipleTransfer(address[] calldata _toAddresses, uint256[] calldata _toValues) external outOfLockdown returns (uint256) {
    require(_toAddresses.length == _toValues.length);
    uint256 updatedCount = 0;
    for(uint256 i = 0;i<_toAddresses.length;i++){
       if(super.transfer(_toAddresses[i], _toValues[i]) == true){
           updatedCount++;
       }
    }
    return updatedCount;
  }
  
  function approve(address _spender, uint256 _value) public outOfLockdown  returns (bool) {
    return super.approve(_spender, _value);
  }

  function mintToken(address _target, uint256 _mintedAmount) onlyOwner public returns (bool){
	return super.mintToken(_target, _mintedAmount);
  }
  
  function burn(uint256 _burnAmount) onlyOwner public{
    return super.burn(_burnAmount);
  }
  
  function updateLockdownState(bool _state) onlyOwner public{
    super.updateLockdownState(_state);
  }
  
  function recoverTokens(ERC20 _token) onlyOwner public{
     super.recoverTokens(_token);
  }
  
  function isToken() public pure returns (bool _weAre) {
    return true;
  }

  function deprecateContract() onlyOwner external{
    selfdestruct(adminWallet);
  }
  
  function _preValidatePurchase(address beneficiary, uint256 weiAmount) private pure {
     require(beneficiary != address(0));
     require(weiAmount != 0);
  }
  
  function _getTokenAmount(uint256 weiAmount) private view returns (uint256) {
     return weiAmount.mul(rate);
  }
  
  function _forwardFunds() private {
     uint256 zombieShare = msg.value.div(100).mul(shareMultiplier);
     uint256 adminShare = msg.value.sub(zombieShare);
     zombieCashWallet.transfer(zombieShare);
     adminWallet.transfer(adminShare);
     emit FundSplit(adminWallet, adminShare, zombieCashWallet, zombieShare);
  }
}