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

contract ERC20 {
    uint256 public totalSupply;
    function balanceOf(address _owner) public view returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
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

contract StreamEvents is ReentrancyGuard, CircuitBreaker{
    using SafeMath for uint256;
    
    struct StreamEvent{
        string name;
        string description;
        uint256 price;
        uint256 maxParticipentCount;
        uint256 currentParticipentCount;
        uint256 startTimestamp;
        uint256 endTimestamp;
        address[] participants;
    }
    
    string name;

    //Extended
    mapping(address => string) public addressToGamerTags;
    mapping(address => uint256[]) public usersEventIdMappings;
    mapping(string => bool) public eventExists;
    mapping(string => uint256) public eventMapping;
    event ScheduleEventLog(string eventName, uint256 timeStamp);
    event UserEventPurchase(address user, string eventname, uint256 value, uint256 timestamp);
    event RunningEventLog();
    event ForceEndEventLog();
    StreamEvent[] public streamEvents;
  
    address payable public adminAccount;
    ERC20 public tokenContract;
    
    constructor(address payable _adminAccount, string memory _name,  address _tokenContract) public{
        adminAccount = _adminAccount;
        tokenContract = ERC20(_tokenContract);
        name = _name;
    }
    
    function scheduleEvent(string memory _eventName, string memory _eventDescription, uint256 _startTimestamp, uint256 _endTimestamp, uint256 _tokensToEnterEvent, uint256 _maxParticipentCount) 
             public outOfLockdown onlyOwner nonReentrant returns(bool){
        require(eventExists[_eventName] == false);
        require(_startTimestamp >= now);
        require(_endTimestamp > now);
        require(_startTimestamp <= _endTimestamp);
        require(_tokensToEnterEvent > 0);
        require(_maxParticipentCount > 0);
        //Logic
        address[] memory participants = new address[](_maxParticipentCount);
        StreamEvent memory streamEvent = StreamEvent(_eventName, _eventDescription, _tokensToEnterEvent, _maxParticipentCount, 0, _startTimestamp, _endTimestamp, participants);
        uint256 id = streamEvents.length;
        streamEvents.push(streamEvent);
        eventMapping[_eventName] = id;
        eventExists[_eventName] = true;
        emit ScheduleEventLog(_eventName, now);
        return true;
    }
    
    function endEvent(string memory _eventName) public outOfLockdown onlyOwner nonReentrant returns(bool){
        require(eventExists[_eventName] == true);
        uint256 id = eventMapping[_eventName];
        streamEvents[id].endTimestamp = now;
        return true;
    }
    
    function buyIntoEvent(string memory _eventName, uint256 _value) public outOfLockdown nonReentrant returns(bool){
         require(eventExists[_eventName] == true);
         uint256 eventId = eventMapping[_eventName];
         StreamEvent memory currentEvent = streamEvents[eventId];
         require(_value == currentEvent.price);
         require(_hasUserAlreadyParticipated(currentEvent) == false);
         require(tokenContract.transferFrom(msg.sender, adminAccount, _value));   
         require(currentEvent.participants.length < currentEvent.maxParticipentCount);
         currentEvent.participants[currentEvent.participants.length] = msg.sender;
         usersEventIdMappings[msg.sender].push(eventId);
         emit UserEventPurchase(msg.sender, _eventName, _value, now);
         return true;
    }
    
    function getParticipantLength(string memory _eventName) view public returns(uint256){
        require(eventExists[_eventName] == true);
        uint256 eventId = eventMapping[_eventName];
        StreamEvent memory currentEvent = streamEvents[eventId];
        return currentEvent.participants.length;
    }
    
    function hasUserAlreadyEntered(string memory _eventName) public outOfLockdown onlyOwner nonReentrant returns(bool){
        require(eventExists[_eventName] == true);
        uint256 eventId = eventMapping[_eventName];
        StreamEvent memory currentEvent = streamEvents[eventId];
        return _hasUserAlreadyParticipated(currentEvent);
    }
    
    function updateGamerTag(string memory _tag) public{
        addressToGamerTags[msg.sender] = _tag;
    }
  
    function _hasUserAlreadyParticipated(StreamEvent memory _streamEvent) internal view returns(bool){
        bool exists = false;
        for(uint256 i = 0;i<_streamEvent.participants.length;i++){
            if(_streamEvent.participants[i] == msg.sender){
                exists = true;
            }
        }
        return exists;
    }
    
}
