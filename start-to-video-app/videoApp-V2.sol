pragma solidity ^0.5.9;
pragma experimental ABIEncoderV2;

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

contract VideoApp {
    using SafeMath for uint256;
    
    struct Video{
        uint256 id;
        string name;
        string[] segments;
        uint256 timestamp;
    }

    struct PartialVideo{
        uint256 id;
        string name;
        string content;
        uint256 segmentsIndex;
        uint256 segmentTotalCount;
        uint256 timestamp;
    }
    
    Video[] videos;
    mapping(uint256 => address) private videoIdToOwner;
    mapping(string => uint256) private videoNameToIndex;
    mapping(address => uint256[]) private ownersVideoIndexes;
    mapping(string => bool) private videoExists;
    mapping(string => bool) private completeVideoUploaded;
    mapping(string => uint256) private segmentTracker;
    
    event VideoUploadStarted(address indexed sender, string indexed name, uint256 timestamp);
    event VideoUploadComplete(string videoName, uint256 segmentLength, uint256 timestamp);
    
    constructor() public{}
    
    function AddVideoSegmentToNewOrExisting(string memory name, string memory segment, uint256 segmentNumber, bool lastSegment) public returns(bool){
        //Simple checks to ensure data quality
        require(completeVideoUploaded[name] == false);
        //Add to new or existing video obj
        if(segmentNumber == 0){
             require(videoExists[name] == false);
             _addnewVideo(name, segment);
             emit VideoUploadStarted(msg.sender, name, now);
        }else{
             require(videoExists[name]);
             uint256 videoIndex = videoNameToIndex[name];
             uint256 currentLength = videos[videoIndex].segments.length;
             require(segmentNumber == currentLength);
             _addToExistingVideo(name, segment);
        }
        //Seal off video if it is the last segment
        if(lastSegment == true){
            completeVideoUploaded[name] = true;
            uint256 videoIndex = videoNameToIndex[name];
            segmentTracker[name] = videos[videoIndex].segments.length;
            emit VideoUploadComplete(name, segmentTracker[name], now);
        }
        return true;
    }
    
    function _addnewVideo(string memory name, string memory segment) internal{
        uint256 id = videos.length;
        string[] memory newSegmentSet = new string[](1);
        newSegmentSet[0] = segment;
        Video memory video = Video(id, name, newSegmentSet, now);
        videos.push(video);
        videoExists[video.name] = true;
        videoNameToIndex[video.name] = video.id;
        videoIdToOwner[video.id] = msg.sender;
        ownersVideoIndexes[msg.sender].push(video.id);
        completeVideoUploaded[name] = false;
    }
    
    function _addToExistingVideo(string memory name, string memory segment) internal{
        uint256 videoIndex = videoNameToIndex[name];
        videos[videoIndex].segments.push(segment);
    }
    
    function GetVideoSegment(string memory name, uint256 currentSegementId) public view returns(PartialVideo memory){
        require(videoExists[name] == true);
        //Get video
        uint256 indexOfVideo = videoNameToIndex[name];
        Video memory video = videos[indexOfVideo];
        //Get chunk to return
        return PartialVideo(video.id, video.name, video.segments[currentSegementId], currentSegementId, video.segments.length, video.timestamp);
    }
    
    function GetVideoSegmentsContentOnly(string memory name, uint256 currentSegementId) public view returns(string memory){
        require(videoExists[name] == true);
        //Get video
        uint256 indexOfVideo = videoNameToIndex[name];
        Video memory video = videos[indexOfVideo];
        //Get chunk to return
        return video.segments[currentSegementId];
    }
    
    function doesVideoNameExist(string memory name) public returns(bool){
        return videoExists[name];
    }
    
    function getOwnersVideoIndexes(address owner) public returns(uint256[] memory){
        return ownersVideoIndexes[owner];
    }
    
}
